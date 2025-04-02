node('main_worker_arm64') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Deploy AWS GitHub Runner") {

            def flags = "" 
            if ("true".equals(env.DESTROY)) {
                flags = "--destroy"
            }
            sh "pipenv run python3.10 -m github_aws_runners.deploy_aws_github_runner ${flags}"
        }
    }
}