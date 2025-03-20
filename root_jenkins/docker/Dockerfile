FROM jenkins/jenkins:2.502-jdk17

USER root

ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

COPY ./root_jenkins/docker/create_ssl_cert.sh ./create_ssl_cert.sh
RUN chmod +x create_ssl_cert.sh
RUN ./create_ssl_cert.sh

USER jenkins
COPY ./root_jenkins/jcasc/plugins.txt /var/plugins.txt
RUN jenkins-plugin-cli --plugin-file /var/plugins.txt

ENV JENKINS_OPTS --httpPort=-1 --httpsPort=8443 --httpsKeyStore=/var/jenkins.jks --httpsKeyStorePassword=changeme