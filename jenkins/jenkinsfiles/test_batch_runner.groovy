node('basic_arm64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage('Install python libs') {
            sh "cp batch_runner/test/Pipfile* ."
            sh "./codeartifact/pipenv_install_with_codeartifact.sh ${env.MAIN_AWS_REGION} ${env.MAIN_AWS_PROFILE} /${env.NAMESPACE}/codeartifact/ofirydevops_main"
        }

        stage("Test Batch Runner") {
            sh "pipenv run python3.10 -m batch_runner.test.test"
        }
    }
}
