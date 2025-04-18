node('basic_arm64_100GB') {
    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
        }

        stage('Run Test') {
            echo "Hello World"
        }
    }
}