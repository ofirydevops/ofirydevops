#!/bin/bash
set -e

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
