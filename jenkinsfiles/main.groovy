node('main_worker_arm64') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Hello World") {
            echo "Hello World"
        }
    }
}