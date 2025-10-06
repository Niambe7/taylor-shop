Introduction
Ce projet déploie un environnement PrestaShop entièrement automatisé sur AWS avec :
ALB pour le load balancing.


ASG (Auto Scaling Group) pour les instances EC2 exécutant PrestaShop dans Docker.


RDS MySQL pour la base de données.


EFS pour le stockage persistant de /var/www/html.


SSM Parameter Store pour stocker les mots de passe et secrets en toute sécurité.


Le projet utilise Terraform pour la création et gestion des ressources, et un user_data personnalisé pour initialiser le conteneur PrestaShop.

Architecture
[Utilisateur / Navigateur]
          |
       Internet
          |
        ALB (HTTP/HTTPS)
          |
   +------+------+
   |             |
ASG EC2 (Docker PrestaShop)
   |             \
   |              \
   v               v
  EFS           RDS MySQL
  (/var/www/html)

ALB → cible les instances EC2 via un Target Group.


EC2 → monte EFS sur /mnt/efs/psdata et lance PrestaShop.


RDS → base MySQL sécurisée, accessible uniquement depuis les EC2.


SSM → stocke le mot de passe MySQL et autres secrets.


EFS → persistance des fichiers PrestaShop (images, thèmes, modules, etc.).



Prérequis
AWS CLI configuré avec les droits IAM pour créer EC2, ALB, RDS, EFS, SSM.


Terraform >= 1.5


Docker et Amazon Linux 2 pour EC2


Une VPC avec subnets publics et privés


Accès à un bucket EFS et RDS existant ou création via Terraform



Déploiement avec Terraform
Initialiser Terraform :


terraform init

Vérifier le plan :


terraform plan -out=tfplan

Appliquer le plan :


terraform apply tfplan

Sorties importantes :


alb_dns_name → DNS de l’ALB pour configurer PrestaShop.


tg_arn → Target Group ARN (utile pour debugging).



Gestion du conteneur PrestaShop
Le user_data.sh initialise PrestaShop automatiquement sur chaque instance EC2 :
Met à jour le système et installe Docker.


Monte EFS sur /mnt/efs/psdata.


Récupère le mot de passe de la DB depuis SSM Parameter Store.


Lance PrestaShop avec les variables :


PS_DOMAIN = DNS de l’ALB


PS_INSTALL_AUTO=1 pour l’installation automatique


PS_HANDLE_DYNAMIC_DOMAIN=1 pour gérer correctement les liens et images


Commandes utiles pour debugging :
# Vérifier les conteneurs
docker ps

# Accéder au container PrestaShop
docker exec -it prestashop bash

# Rafraîchir le cache et reconstruire les thumbs/images
rm -rf /var/www/html/var/cache/*
php /tmp/rebuild_thumbs.php

# Vérifier le host
curl -I -H "Host: <ALB_DNS>" http://127.0.0.1/themes/classic/assets/css/theme.css


Mise à jour et maintenance
Pour mettre à jour PrestaShop :


docker pull prestashop/prestashop:<nouvelle_version>
docker rm -f prestashop
docker run ... # relancer avec la même commande user_data

Pour appliquer des modifications Terraform :


terraform plan -out=tfplan
terraform apply tfplan

Pour purger le cache PrestaShop et reconstruire les assets :


docker exec -it prestashop bash -lc 'rm -rf /var/www/html/var/cache/*; apachectl -k graceful'

Pour reconstruire les images produits si elles sont manquantes :


docker exec -it prestashop bash -lc 'php -d memory_limit=-1 /tmp/rebuild_thumbs.php'


Résolution des problèmes courants
Problème
Solution
CSS ou JS cassé
Vérifier les réglages PS_CSS_THEME_CACHE / PS_JS_THEME_CACHE, vider cache PrestaShop, reconstruire le .htaccess.
Images produits manquantes
Vérifier /var/www/html/img/p/..., reconstruire avec rebuild_thumbs.php.
Redirection vers l’adresse privée
Configurer PS_DOMAIN dans parameters.php et user_data.
404 sur ressources
Vérifier .htaccess et mod_rewrite activé, rafraîchir cache et droits www-data.


Restauration après destruction
EFS contient tous les fichiers persistants (/var/www/html), donc vos thèmes et images sont conservés.


RDS doit être sauvegardé via snapshots avant un destroy.


Après un destroy / re-création :


Lancer Terraform apply.


Les instances EC2 se reconnectent automatiquement à EFS.


PrestaShop reprend son état grâce à la persistance des fichiers et base de données.



Notes importantes
Toujours tester les modifications sur un environnement de staging avant prod.


Ne pas hardcoder les mots de passe ou le domaine dans le conteneur : utiliser SSM + variables Terraform.


Tous les chemins /var/www/html sont persistants via EFS, ce qui permet de répliquer facilement.
