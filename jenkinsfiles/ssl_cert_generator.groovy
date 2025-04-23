node('basic_arm64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Generate SSL Cert") {

            def domain = env.domain

            sh "pipenv run python3.10 -m ssl_certs_creator.renew_ssl_cert --domain ${domain}"
        }
    }
}
