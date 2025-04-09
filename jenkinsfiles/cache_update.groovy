def ARCH_CONF = [
    "arm64" : [
        "node" : "arm64_4vcpu_16gb_100gb"
    ],
    "amd64" : [
        "node" : "amd64_4vcpu_16gb_100gb"
    ]
]

def NODE_LABEL = ARCH_CONF.get(env.arch).get('node')

node(NODE_LABEL) {
    ansiColor('xterm') {

        def condaEnv       = env.conda_env
        def arch           = env.arch
        def dockerImageTag = env.BUILD_TAG
        def service        = "main_update_cache_${arch}"
        def nodeLabel      = NODE_LABEL
        def processor      = env.processor

        if ("gpu".equals(processor)) {
            service = "${service}_gpu"
        }

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkinsfiles/utils.groovy'
            utils.setUpDockerEnv(this)
        }

        stage("Update CondaEnv Docker Cache") {
            sh "DOCKER_IMAGE_TAG=${dockerImageTag} \
                CONDA_ENV=${condaEnv} \
                docker compose -f data_science/docker/docker-compose.yml build ${service} --builder dc"
        }
    }
}