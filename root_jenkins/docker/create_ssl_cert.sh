apt update
apt install python3-certbot-dns-route53 certbot -y

certbot certonly \
    --dns-route53 \
    -d ofirydevops.com \
    -d *.ofirydevops.com \
    --non-interactive \
    --agree-tos \
    --email yahavofir@gmail.com \
    --no-eff-email

export CERT_FILE=/etc/letsencrypt/live/ofirydevops.com/cert.pem
export CERT_CHAIN_FILE=/etc/letsencrypt/live/ofirydevops.com/chain.pem
export CERT_KEY_FILE=/etc/letsencrypt/live/ofirydevops.com/privkey.pem

openssl pkcs12 -export -out jenkins.p12 \
    -passout 'pass:changeme' \
    -inkey ${CERT_KEY_FILE} \
    -in ${CERT_FILE} \
    -certfile ${CERT_CHAIN_FILE} \
    -name ofirydevops.com

keytool -importkeystore \
    -srckeystore jenkins.p12 \
    -srcstoretype PKCS12 \
    -srcstorepass 'changeme' \
    -srcalias ofirydevops.com \
    -deststoretype JKS \
    -destkeystore jenkins.jks \
    -deststorepass 'changeme' \
    -destalias ofirydevops.com

cp jenkins.jks /var/jenkins.jks
