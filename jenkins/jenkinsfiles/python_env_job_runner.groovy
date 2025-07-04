
node(env.node) {
    ansiColor('xterm') {

        def maxTimeoutInMinutes = 80
        def timeoutInMinutes    = env.timeout_in_minutes.toInteger()
        def dockerImageTag      = env.BUILD_TAG
        def command             = env.command
        def pyEnvConfFile       = env.py_env_conf_file

        def workdir             = "guest_repo"
        def repository          = env.repository
        def repositoryRef       = env.repository_ref
        def credentialsId       = env.credentials_id

        if (timeoutInMinutes > maxTimeoutInMinutes) {
            timeoutInMinutes = maxTimeoutInMinutes
        }

        stage('Checkout ofirydevops') {
            checkout scm
            def utils = load 'jenkins/local_lib/utils.groovy'
            utils.setupGlobalConf(this)
        }

        stage('Checkout repo') {
            dir(workdir) {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: repositoryRef]],
                    userRemoteConfigs: [[
                        url: "https://github.com/${repository}.git",
                        credentialsId: credentialsId
                    ]]
                ])
            }        
        }


        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Build Conda Env Docker") {
            sh "pipenv run python3.10 -u -m python_env_runner.scripts.build_py_env \
                                            --py-env-conf-file ${workdir}/${pyEnvConfFile} \
                                            --docker-image-tag ${dockerImageTag} \
                                            --target runtime \
                                            --workdir ${workdir}"
        }

        stage("Run Conda Env") {

            timeout(time: timeoutInMinutes, unit: 'MINUTES') {
                sh "pipenv run python3.10 -u -m python_env_runner.scripts.run_py_env \
                                             --docker-image-tag ${dockerImageTag} \
                                             --entrypoint \"${command}\""
            }
        }
    }
}