def ARCH_CONF = [
    "arm64" : [
        "node" : "arm64_4vcpu_16gb_30gb",
        "dc_service" : "main_arm64_update_cache"
    ],
    "amd64" : [
        "node" : "amd64_4vcpu_16gb_30gb",
        "dc_service" : "main_amd64_update_cache"

    ]
]

// ARCH = env.getEnvironment().get("arch", "amd64")

node(ARCH_CONF.get(env.arch).get('node')) {
    ansiColor('xterm') {

        def condaEnv = env.conda_env
        def arch = env.arch
        def dockerImageTag = env.BUILD_TAG
        def dcService = ARCH_CONF.get(arch).get('dc_service')


        stage('Checkout') {
            checkout scm
        }

        stage("Update CondaEnv Docker Cache") {
            sh "DOCKER_IMAGE_TAG=${dockerImageTag} \
                CONDA_ENV=${condaEnv} \
                docker compose -f data_science/docker/docker-compose.yml build ${dcService} --builder dc"
        }
    }
}