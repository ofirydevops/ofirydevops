
node(env.node) {
    ansiColor('xterm') {

        def maxUptime      = 80
        def uptimeInMinuts = env.uptime_in_minutes.toInteger()
        def dockerImageTag = env.BUILD_TAG
        def gitRef         = env.ref
        def condaEnv       = env.conda_env
        def nodeLabel      = env.node
        def service        = null
        def servicePrefix  = "remote_dev"

        if (uptimeInMinuts > maxUptime) {
            uptimeInMinuts = maxUptime
        }

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkinsfiles/utils.groovy'
            service = utils.getDcService(servicePrefix, nodeLabel)
            utils.setUpDockerEnv(this)
        }

        stage('Display Public IP') {
            String ip = sh (script: "curl -s http://169.254.169.254/latest/meta-data/public-ipv4", returnStdout: true).trim()
            echo("Public IP: ${ip}")
        }

        stage("Build Conda Env Docker") {
            sh "DOCKER_IMAGE_TAG=${dockerImageTag} \
                GIT_REF=${gitRef} \
                CONDA_ENV=${condaEnv} \
                docker compose -f data_science/docker/docker-compose.yml build ${service} --builder dc"
        }


        stage("Run Conda Env") {

            timeout(time: uptimeInMinuts, unit: 'MINUTES') {
            
                sh "DOCKER_IMAGE_TAG=${dockerImageTag} \
                    docker compose -f data_science/docker/docker-compose.yml run --service-ports ${service}"
            }
        }
    }
}