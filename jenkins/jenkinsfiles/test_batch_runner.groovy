node('basic_arm64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage('Install python libs') {
            sh "cp batch_runner/test/Pipfile* ."
            sh "./codeartifact/pipenv_install_with_codeartifact.sh eu-central-1 OFIRYDEVOPS /codeartifact/batch_runner_main"
        }

        stage("Test Batch Runner") {
            sh "pipenv run python3.10 -m batch_runner.test.test"
        }
    }
}
