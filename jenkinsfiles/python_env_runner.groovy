
node(env.node) {
    ansiColor('xterm') {

        def maxUptime      = 80
        def timeoutInMinutes = env.timeout_in_minutes.toInteger()
        def dockerImageTag = env.BUILD_TAG
        def condaEnv       = env.conda_env
        def nodeLabel      = env.node
        def service        = null
        def servicePrefix  = "main"

        if (timeout > maxUptime) {
            timeoutInMinutes = maxUptime
        }

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkinsfiles/utils.groovy'
            service = utils.getDcService(servicePrefix, nodeLabel)
            utils.setUpDockerEnv(this)
        }

        stage("Build Conda Env Docker") {
            sh "DOCKER_IMAGE_TAG=${dockerImageTag} \
                CONDA_ENV=${condaEnv} \
                docker compose -f data_science/docker/docker-compose.yml build ${service}"
        }


        stage("Run Conda Env") {

            timeout(time: timeoutInMinutes, unit: 'MINUTES') {
                sh "DOCKER_IMAGE_TAG=${dockerImageTag} \
                    docker compose -f data_science/docker/docker-compose.yml run ${service}"
            }
        }
    }
}