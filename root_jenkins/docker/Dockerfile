FROM jenkins/jenkins:2.500-jdk17

USER root

ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY

COPY ./root_jenkins/docker/create_ssl_cert.sh ./create_ssl_cert.sh
RUN chmod +x create_ssl_cert.sh
RUN ./create_ssl_cert.sh

USER jenkins
COPY ./root_jenkins/jcasc/plugins.txt /var/plugins.txt
RUN jenkins-plugin-cli --plugin-file /var/plugins.txt

COPY ./root_jenkins/terraform/jcasc_config_tmp.yaml /var/jenkins_home/jcasc/main.yaml
# RUN chmod -R 600 /var/jenkins_home/jcasc/
# RUN chown -R 1000:1000 /var/jenkins_home/jcasc/

ENV JENKINS_OPTS --httpPort=-1 --httpsPort=8443 --httpsKeyStore=/var/jenkins.jks --httpsKeyStorePassword=changeme