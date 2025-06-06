node('basic_amd64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage("Build Batch Runner") {

            sh "cd batch_runner/terraform && \
                terraform init -backend-config=../../backend.config && \
                terraform apply -auto-approve"
        }
    }
}
