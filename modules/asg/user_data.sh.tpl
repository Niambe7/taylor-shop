#!/bin/bash
set -euo pipefail

REGION="${region}"
PARAM_DB_PASS="${db_password_param_name}"
DB_ENDPOINT="${db_endpoint}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
PS_IMAGE_TAG="${prestashop_image_tag}"
PS_DOMAIN="${alb_dns_name}"

# Packages
yum update -y
amazon-linux-extras install docker -y
yum install -y awscli amazon-efs-utils
systemctl enable docker
systemctl start docker

# EFS mount
mkdir -p /mnt/efs/psdata
# tentative avec tls si besoin
mount -t efs ${efs_id}:/ /mnt/efs || mount -t efs -o tls ${efs_id}:/ /mnt/efs
if ! grep -q "/mnt/efs" /etc/fstab; then
  echo "${efs_id}.efs.${region}.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab
fi

# DB password from SSM (SecureString)
DB_PASS=$(aws ssm get-parameter --name "$${PARAM_DB_PASS}" --with-decryption --query "Parameter.Value" --output text --region "$${REGION}")

# PrestaShop container
docker pull prestashop/prestashop:$${PS_IMAGE_TAG}
docker rm -f prestashop || true
docker run -d \
  --name prestashop \
  --restart unless-stopped \
  -p 80:80 \
  -v /mnt/efs/psdata:/var/www/html \
  -e DB_SERVER=$${DB_ENDPOINT} \
  -e DB_NAME=$${DB_NAME} \
  -e DB_USER=$${DB_USER} \
  -e DB_PASSWD=$${DB_PASS} \
  -e PS_INSTALL_AUTO=1 \
  -e PS_HANDLE_DYNAMIC_DOMAIN=1 \
  -e PS_DOMAIN=$${PS_DOMAIN} \
  prestashop/prestashop:$${PS_IMAGE_TAG}
