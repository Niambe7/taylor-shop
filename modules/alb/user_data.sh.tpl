#!/bin/bash
set -euo pipefail


REGION="${region}"
PARAM_DB_PASS="${db_password_param_name}"
DB_ENDPOINT="${db_endpoint}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
EFS_ID="${efs_id}"
PS_IMAGE_TAG="${prestashop_image_tag}"


# Packages
yum update -y
amazon-linux-extras enable docker
yum install -y docker awscli amazon-efs-utils
systemctl enable docker && systemctl start docker


# EFS mount
mkdir -p /mnt/efs/psdata
EFS_DNS="${EFS_ID}.efs.${REGION}.amazonaws.com"
mount -t efs ${EFS_ID}:/ /mnt/efs
if ! grep -q "/mnt/efs" /etc/fstab; then
echo "${EFS_DNS}:/ /mnt/efs efs defaults,_netdev 0 0" >> /etc/fstab
fi
mkdir -p /mnt/efs/psdata


# DB password from SSM (SecureString)
DB_PASS=$(aws ssm get-parameter --name "${PARAM_DB_PASS}" --with-decryption --query "Parameter.Value" --output text --region "${REGION}")


# PrestaShop container
/usr/bin/docker pull prestashop/prestashop:${PS_IMAGE_TAG}
/usr/bin/docker rm -f prestashop || true
/usr/bin/docker run -d \
--name prestashop \
--restart unless-stopped \
-p 80:80 \
-v /mnt/efs/psdata:/var/www/html \
-e DB_SERVER=${DB_ENDPOINT} \
-e DB_NAME=${DB_NAME} \
-e DB_USER=${DB_USER} \
-e DB_PASSWD=${DB_PASS} \
-e PS_INSTALL_AUTO=1 \
-e PS_HANDLE_DYNAMIC_DOMAIN=1 \
prestashop/prestashop:${PS_IMAGE_TAG}