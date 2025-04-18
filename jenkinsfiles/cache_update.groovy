node(env.node) {
    ansiColor('xterm') {

        def condaEnv       = env.conda_env
        def dockerImageTag = env.BUILD_TAG
        def servicePrefix  = "main_update_cache"
        def nodeLabel      = env.node
        def gpu            = env.gpu
        def service        = null

        if ("true".equals(gpu)) {
            nodeLabel = "${nodeLabel}_gpu"
        }

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkinsfiles/utils.groovy'
            utils.setUpEcrAuthAndFilesPermission(this)
            service = utils.getDcService(servicePrefix, nodeLabel)
        }

        stage("Update CondaEnv Docker Cache") {
            sh "DOCKER_IMAGE_TAG=${dockerImageTag} \
                CONDA_ENV=${condaEnv} \
                docker compose -f data_science/docker/docker-compose.yml build ${service}" // --builder dc"
        }
    }
}