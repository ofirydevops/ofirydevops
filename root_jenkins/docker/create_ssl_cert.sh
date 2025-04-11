#!/bin/bash

DOMAIN=$1

apt update
apt install python3-certbot-dns-route53 certbot -y

certbot certonly -v \
    --dns-route53 \
    -d ${DOMAIN} \
    -d *.${DOMAIN} \
    --non-interactive \
    --agree-tos \
    --email yahavofir@gmail.com \
    --no-eff-email

export CERT_FILE=/etc/letsencrypt/live/${DOMAIN}/cert.pem
export CERT_CHAIN_FILE=/etc/letsencrypt/live/${DOMAIN}/chain.pem
export CERT_KEY_FILE=/etc/letsencrypt/live/${DOMAIN}/privkey.pem

openssl pkcs12 -export -out jenkins.p12 \
    -passout 'pass:changeme' \
    -inkey ${CERT_KEY_FILE} \
    -in ${CERT_FILE} \
    -certfile ${CERT_CHAIN_FILE} \
    -name ${DOMAIN}

keytool -importkeystore \
    -srckeystore jenkins.p12 \
    -srcstoretype PKCS12 \
    -srcstorepass 'changeme' \
    -srcalias ${DOMAIN} \
    -deststoretype JKS \
    -destkeystore jenkins.jks \
    -deststorepass 'changeme' \
    -destalias ${DOMAIN}

cp jenkins.jks /var/jenkins.jks
