#!/bin/bash

set -e

apt update
apt install python3-certbot-dns-route53 certbot unzip less -y
# curl unzip less jq openjdk-17-jdk

curl "https://awscli.amazonaws.com/awscli-exe-linux-$(arch).zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

certbot certonly -v \
    --dns-route53 \
    -d ${DOMAIN} \
    -d *.${DOMAIN} \
    --non-interactive \
    --agree-tos \
    --email ${EMAIL} \
    --no-eff-email

export CERT_FILE=/etc/letsencrypt/live/${DOMAIN}/cert.pem
export CERT_CHAIN_FILE=/etc/letsencrypt/live/${DOMAIN}/chain.pem
export CERT_KEY_FILE=/etc/letsencrypt/live/${DOMAIN}/privkey.pem

aws ssm put-parameter --name /sslcerts/ofirydevops.com/cert       --type SecureString --value file://${CERT_FILE}       --overwrite
aws ssm put-parameter --name /sslcerts/ofirydevops.com/chain      --type SecureString --value file://${CERT_CHAIN_FILE} --overwrite
aws ssm put-parameter --name /sslcerts/ofirydevops.com/privateKey --type SecureString --value file://${CERT_KEY_FILE}   --overwrite
