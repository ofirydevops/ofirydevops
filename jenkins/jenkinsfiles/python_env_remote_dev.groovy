
node(env.node) {
    ansiColor('xterm') {

        def maxUptime      = 80
        def uptimeInMinuts = env.uptime_in_minutes.toInteger()
        def dockerImageTag = env.BUILD_TAG
        def pyEnvConfFile  = env.py_env_conf_file
        def gitUserEmail   = env.git_user_email
    
        def workdir        = "guest_repo"
        def repository     = env.repository
        def repositoryRef  = env.repository_ref
        def credentialsId  = env.credentials_id
        String IP

        if (uptimeInMinuts > maxUptime) {
            uptimeInMinuts = maxUptime
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

        stage('Display Public IP') {
            IP = sh (script: "curl -s http://169.254.169.254/latest/meta-data/public-ipv4", returnStdout: true).trim()
            echo("Public IP: ${IP}")
        }

        stage("Build Python Env Docker") {
            sh "pipenv run python3.10 -u -m python_env_runner.scripts.build_py_env \
                                            --py-env-conf-file ${pyEnvConfFile} \
                                            --docker-image-tag ${dockerImageTag} \
                                            --target remote_dev \
                                            --git-ref ${repositoryRef} \
                                            --git-user-email ${gitUserEmail} \
                                            --workdir ${workdir}"
        }

        stage("Run Python Env") {

            echo "For remote development run ssh command: ssh to root@${IP} on port 5000 -o StrictHostKeyChecking=no"

            timeout(time: uptimeInMinuts, unit: 'MINUTES') {
                sh "pipenv run python3.10 -u -m python_env_runner.scripts.run_py_env \
                                             --remote-dev \
                                             --docker-image-tag ${dockerImageTag}"
            }
        }
    }
}