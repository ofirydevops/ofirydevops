node('basic_arm64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage("Build CodeArtifact") {

            sh "cd codeartifact/terraform && \
                terraform init -backend-config=../../backend.config && \
                terraform apply -auto-approve"
        }
    }
}
