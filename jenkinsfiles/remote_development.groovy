
node(env.node) {
    ansiColor('xterm') {

        def maxUptime = 80
        def uptimeInMinuts = env.uptime_in_minutes.toInteger()
        def serviceSuffix = "amd64"
        if (env.node.toLowerCase().contains("arm64")) {
            serviceSuffix = "arm64"
        }
        if (env.node.toLowerCase().contains("gpu")) {
            serviceSuffix = "${serviceSuffix}_gpu"
        }
        def service = "remote_dev_${serviceSuffix}"

        if (uptimeInMinuts > maxUptime) {
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
                sh "wget https://github.com/docker/buildx/releases/download/v0.22.0/buildx-v0.22.0.linux-arm64 -O docker-buildx && \
                    mkdir -p ~/.docker/cli-plugins && \
                    mv docker-buildx ~/.docker/cli-plugins/docker-buildx && \
                    chmod +x ~/.docker/cli-plugins/docker-buildx && \
                    docker buildx version"
                sh "docker buildx create --name docker-container --driver docker-container --use --bootstrap"
                sh "docker compose -f data_science/docker/docker-compose.yml build ${service}"
            }
        }


        stage("Run Conda Env") {

            timeout(time: uptimeInMinuts, unit: 'MINUTES') {
                withEnv([
                    "DOCKER_IMAGE_TAG=${env.BUILD_TAG}"
                ]) {   
                    sh "docker compose -f data_science/docker/docker-compose.yml run --service-ports ${service}"
                }
            }
        }
    }
}