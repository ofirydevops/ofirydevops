
node(env.node) {
    ansiColor('xterm') {

        def maxTimeoutInMinutes = 80
        def timeoutInMinutes    = env.timeout_in_minutes.toInteger()
        def dockerImageTag      = env.BUILD_TAG
        def condaEnv            = env.conda_env
        def command             = env.command
        def pyEnvConfFile       = env.py_env_conf_file

        if (timeoutInMinutes > maxTimeoutInMinutes) {
            timeoutInMinutes = maxTimeoutInMinutes
        }

        stage('Checkout') {
            checkout scm
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Build Conda Env Docker") {
            sh "pipenv run python3.10 -u -m data_science.scripts.build_py_env \
                                            --py-env-conf-file ${pyEnvConfFile} \
                                            --docker-image-tag ${dockerImageTag} \
                                            --target runtime"
        }

        stage("Run Conda Env") {

            timeout(time: timeoutInMinutes, unit: 'MINUTES') {
                sh "pipenv run python3.10 -u -m data_science.scripts.run_py_env \
                                             --docker-image-tag ${dockerImageTag} \
                                             --cmd \"${command}\""
            }
        }
    }
}