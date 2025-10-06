#!/bin/bash
set -euxo pipefail

# ====== Variables injectées par Terraform ======
REGION="${region}"
PARAM_DB_PASS="${db_password_param_name}"
DB_ENDPOINT="${db_endpoint}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
PS_IMAGE_TAG="${prestashop_image_tag}"
PS_DOMAIN="${alb_dns_name}"       # DNS de l'ALB

EFS_ID="${efs_id}"                # pour clarté dans les commandes

# ====== Paquets de base ======
# (parfois yum est verrouillé au boot, on réessaie gentiment)
for i in {1..5}; do
  if yum makecache fast && yum -y update && amazon-linux-extras install -y docker && yum -y install awscli amazon-efs-utils; then
    break
  fi
  echo "yum lock ou échec transitoire, retry ($i/5)..." && sleep 5
done

systemctl enable docker
systemctl start docker

# ====== Montage EFS ======
mkdir -p /mnt/efs/psdata
# on tente TLS d'abord, puis sans TLS si besoin
mount -t efs -o tls "${EFS_ID}:/" /mnt/efs || mount -t efs "${EFS_ID}:/" /mnt/efs
if ! grep -q "/mnt/efs" /etc/fstab; then
  echo "${EFS_ID}.efs.${REGION}.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab
fi

# ====== Secret DB via SSM ======
DB_PASS=$(aws ssm get-parameter --name "$${PARAM_DB_PASS}" --with-decryption --query "Parameter.Value" --output text --region "$${REGION}")

# ====== Lancement du conteneur PrestaShop ======
docker pull "prestashop/prestashop:$${PS_IMAGE_TAG}" || true
docker rm -f prestashop || true

docker run -d \
  --name prestashop \
  --restart unless-stopped \
  -p 80:80 \
  -v /mnt/efs/psdata:/var/www/html \
  -e DB_SERVER="$${DB_ENDPOINT}" \
  -e DB_NAME="$${DB_NAME}" \
  -e DB_USER="$${DB_USER}" \
  -e DB_PASSWD="$${DB_PASS}" \
  -e PS_INSTALL_AUTO=1 \
  -e PS_HANDLE_DYNAMIC_DOMAIN=1 \
  -e PS_DOMAIN="$${PS_DOMAIN}" \
  "prestashop/prestashop:$${PS_IMAGE_TAG}"

# ====== Attendre qu'Apache réponde dans le conteneur ======
for i in {1..30}; do
  code=$(docker exec prestashop bash -lc 'curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/ || true')
  if echo "$code" | grep -qE '^(200|301|302)$'; then break; fi
  echo "Apache pas prêt (HTTP $code), retry $i/30..." && sleep 3
done

# ====== Apache : mod_rewrite + ServerName + (optionnel) force-host ======
docker exec prestashop bash -lc "a2enmod rewrite >/dev/null 2>&1 || true"
docker exec prestashop bash -lc "printf 'ServerName localhost\n' > /etc/apache2/conf-enabled/servername.conf"

# Redirige toute requête dont l'Host != ALB vers l'ALB (302).
# (Facultatif, mais pratique pour éviter les IP privées ou anciens domaines)
docker exec prestashop bash -lc "cat >/etc/apache2/conf-enabled/force-host.conf <<EOF
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteCond %{HTTP_HOST} !^${PS_DOMAIN//./\\.}$ [NC]
  RewriteRule ^(.*)$ http://${PS_DOMAIN}/\$1 [R=302,L]
</IfModule>
EOF
apachectl -k graceful || true"

# ====== Normalisation PrestaShop (idempotent) ======
# - Force le domaine (HTTP/SSL) sur l'ALB
# - Désactive la redirection canonique (évite les 301 vers l'ancien host)
# - Fait confiance à X-Forwarded-Host derrière ALB
# - Corrige shop_url + génère .htaccess + purge caches
docker exec -e ALB_HOST="$${PS_DOMAIN}" prestashop bash -lc 'php -d memory_limit=-1 -r "
  include \"/var/www/html/config/config.inc.php\";
  Configuration::updateValue(\"PS_SHOP_DOMAIN\", getenv(\"ALB_HOST\"));
  Configuration::updateValue(\"PS_SHOP_DOMAIN_SSL\", getenv(\"ALB_HOST\"));
  Configuration::updateValue(\"PS_CANONICAL_REDIRECT\", \"0\");
  Configuration::updateValue(\"PS_USE_X_FORWARDED_HOST\", \"1\");
  Db::getInstance()->execute(\"UPDATE \"._DB_PREFIX_.\"shop_url SET domain='\".pSQL(getenv(\"ALB_HOST\")).\"', domain_ssl='\".pSQL(getenv(\"ALB_HOST\")).\"', physical_uri='/'\");
  Tools::generateHtaccess();
  @Tools::clearAllCaches();
"'

# ====== (Optionnel) désactiver cache/minify thème au 1er boot ======
docker exec prestashop bash -lc 'php -r "
  include \"/var/www/html/config/config.inc.php\";
  Configuration::updateValue(\"PS_CSS_THEME_CACHE\", 0);
  Configuration::updateValue(\"PS_JS_THEME_CACHE\", 0);
  Configuration::updateValue(\"PS_HTML_THEME_COMPRESSION\", 0);
  Configuration::updateValue(\"PS_HTML_THEME_MINIFY\", 0);
  Configuration::updateValue(\"PS_JS_DEFER\", 0);
"'

# ====== (Optionnel) reconstruire les miniatures manquantes ======
docker exec prestashop bash -lc 'php -d memory_limit=-1 -r "
  include \"/var/www/html/config/config.inc.php\";
  \$types = ImageType::getImagesTypes(\"products\");
  \$rows  = Db::getInstance()->executeS(\"SELECT id_image FROM \"._DB_PREFIX_.\"image\");
  foreach (\$rows as \$r) {
    \$img = new Image((int)\$r[\"id_image\"]);
    \$img->createImgFolder();
    \$base = \$img->getPathForCreation();
    \$src  = \$base.\".jpg\";
    if (!file_exists(\$src)) { continue; }
    foreach (\$types as \$t) {
      \$dst = \$base.\"-\".\$t[\"name\"].\".jpg\";
      if (!file_exists(\$dst)) { ImageManager::resize(\$src, \$dst, (int)\$t[\"width\"], (int)\$t[\"height\"]); }
    }
  }
"'

# Permissions sûres (sur EFS persistant)
docker exec prestashop bash -lc "chown -R www-data:www-data /var/www/html || true"
docker exec prestashop bash -lc "apachectl -k graceful || true"

echo "BOOTSTRAP PRESTASHOP OK — URL: http://$${PS_DOMAIN}"
