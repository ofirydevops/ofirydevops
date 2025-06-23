FROM jenkins/jenkins:2.506-jdk17

USER root

ARG DOMAIN
ARG DOMAIN_CERT_FILE
ARG DOMAIN_CERT_PRIVATE_KEY_FILE
ARG DOMAIN_CERT_CHAIN_FILE

ENV CERT_FILE=cert.pem
ENV CERT_CHAIN_FILE=chain.pem
ENV CERT_KEY_FILE=privatekey.pem

COPY $DOMAIN_CERT_FILE $CERT_FILE
COPY $DOMAIN_CERT_PRIVATE_KEY_FILE $CERT_KEY_FILE
COPY $DOMAIN_CERT_CHAIN_FILE $CERT_CHAIN_FILE

COPY ./tf_modules/jenkins/docker/setup_jenkins_ssl.sh ./setup_jenkins_ssl.sh
RUN chmod +x setup_jenkins_ssl.sh
RUN ./setup_jenkins_ssl.sh

USER jenkins
COPY ./tf_modules/jenkins/docker/plugins.txt /var/plugins.txt
RUN jenkins-plugin-cli --plugin-file /var/plugins.txt

ENV JENKINS_OPTS --httpPort=-1 --httpsPort=8443 --httpsKeyStore=/var/jenkins.jks --httpsKeyStorePassword=changeme
