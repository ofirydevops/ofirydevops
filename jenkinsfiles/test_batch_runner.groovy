node('basic_amd64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
            // def utils = load 'jenkinsfiles/utils.groovy'
            // utils.setUpEcrAuthAndFilesPermission(this)
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Test Batch Runner") {

            sh "pipenv run python3.10 -m batch_runner.test.test"
        }
    }
}
