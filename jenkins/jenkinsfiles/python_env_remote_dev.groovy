
node(env.node) {
    ansiColor('xterm') {

        def maxUptime      = 80
        def uptimeInMinuts = env.uptime_in_minutes.toInteger()
        def dockerImageTag = env.BUILD_TAG
        def pyEnvConfFile  = env.py_env_conf_file
        def gitUserEmail   = env.git_user_email
        String IP

        if (uptimeInMinuts > maxUptime) {
            uptimeInMinuts = maxUptime
        }

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkins/local_lib/utils.groovy'
            utils.setupGlobalConf(this)
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage('Display Public IP') {
            IP = sh (script: "curl -s http://169.254.169.254/latest/meta-data/public-ipv4", returnStdout: true).trim()
            echo("Public IP: ${IP}")
        }

        stage("Build Conda Env Docker") {
            sh "pipenv run python3.10 -u -m python_env_runner.scripts.build_py_env \
                                            --py-env-conf-file ${pyEnvConfFile} \
                                            --docker-image-tag ${dockerImageTag} \
                                            --target remote_dev \
                                            --git-ref ${ref} \
                                            --git-user-email ${gitUserEmail}"
        }

        stage("Run Conda Env") {

            echo "For remote development you can ssh to root@${IP} on port 5000"

            timeout(time: uptimeInMinuts, unit: 'MINUTES') {
                sh "pipenv run python3.10 -u -m python_env_runner.scripts.run_py_env \
                                             --remote-dev \
                                             --docker-image-tag ${dockerImageTag}"
            }
        }
    }
}