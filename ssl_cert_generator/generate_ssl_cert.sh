#!/bin/bash

set -e

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

aws ssm put-parameter --name /${NAMESPACE}/sslcerts/${DOMAIN}/cert       --type SecureString --value file://${CERT_FILE}       --overwrite
aws ssm put-parameter --name /${NAMESPACE}/sslcerts/${DOMAIN}/chain      --type SecureString --value file://${CERT_CHAIN_FILE} --overwrite
aws ssm put-parameter --name /${NAMESPACE}/sslcerts/${DOMAIN}/privateKey --type SecureString --value file://${CERT_KEY_FILE}   --overwrite
