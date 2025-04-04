NODE_ARCH_MAP = [
    'amd64_4vcpu_16gb_30gb' : 'amd64', 
    'main_worker_arm64' : 'arm64', 
    'deep_learning_worker_amd64' : 'amd64', 
    'deep_learning_worker_arm64' : 'arm64'
]

node(env.node) {
    ansiColor('xterm') {

        def maxUptime = 80
        def uptimeInMinuts = env.uptime_in_minutes.toInteger()

        if uptimeInMinuts > maxUptime {
            uptimeInMinuts = maxUptime
        }

        stage('Checkout') {
            checkout scm
        }

        stage('Display Public IP') {
            String ip = sh (script: "curl -s http://169.254.169.254/latest/meta-data/public-ipv4", returnStdout: true).trim()
            echo("Public IP: ${ip}")
        }

        stage("Build Conda Env Docker") {

            withEnv([
                "DOCKER_IMAGE_TAG=${env.BUILD_TAG}",
                "GIT_REF=${env.ref}"
            ]) {   
                sh "docker buildx create --name docker-container--driver docker-container --use --bootstrap"
                sh "docker compose -f data_science/docker/docker-compose.yml build remote_dev_${NODE_ARCH_MAP[env.node]}"
            }
        }


        stage("Run Conda Env") {

            timeout(time: uptimeInMinuts, unit: 'MINUTES') {
                withEnv([
                    "DOCKER_IMAGE_TAG=${env.BUILD_TAG}"
                ]) {   
                    sh "docker compose -f data_science/docker/docker-compose.yml run --service-ports remote_dev_${NODE_ARCH_MAP[env.node]}"
                }
            }
        }
    }
}