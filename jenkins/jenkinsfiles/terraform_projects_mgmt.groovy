node('basic_amd64_100GB') {

    def tfProject = env.tf_project
    def tfAction  = env.tf_action

    ansiColor('xterm') {

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkins/local_lib/utils.groovy'
            utils.setupGlobalConf(this)
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Run TF Action") {

            sh "pipenv run python3.10 -m deployment.tf_manager \
                                         --tf-action ${tfAction} \
                                         --tf-project ${tfProject}"
        }
    }
}
