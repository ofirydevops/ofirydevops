node('basic_arm64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkins/local_lib/utils.groovy'
            utils.setupGlobalConf(this)
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Generate SSL Cert") {

            def domain = env.domain

            sh "pipenv run python3.10 -m ssl_cert_generator.generate_ssl_cert"
        }
    }
}
