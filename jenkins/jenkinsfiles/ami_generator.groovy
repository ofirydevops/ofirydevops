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

        stage("Generate AMI") {
            sh "pipenv run python3.10 -m ami_generator.ami_generator --conf ${env.ami_conf}"
        }
    }
}
