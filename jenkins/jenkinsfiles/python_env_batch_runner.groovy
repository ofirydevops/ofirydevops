
node('basic_arm64_100GB') {
    ansiColor('xterm') {

        def dockerImageTag             = env.BUILD_TAG
        def batchEnv                   = env.batch_env
        def childJobEnterypoint        = env.child_job_entrypoint
        sh "ls -l" 
        

        stage('Checkout') {
            checkout scm
            def utils = load 'jenkins/local_lib/utils.groovy'
            utils.setupGlobalConf(this)
            unstash 'py_env_conf.yaml'
            unstash 'child_jobs_input.yaml'
            sh "ls -l" 
        }

        stage('Install python libs') {
            sh "pipenv install"
        }

        stage("Build Conda Env Docker And Run Batch") {
            sh "pipenv run python3.10 -m python_env_runner.scripts.run_py_env_batch \
                                            --py-env-conf-file py_env_conf.yaml \
                                            --child-jobs-input-file child_jobs_input.yaml \
                                            --docker-image-tag ${dockerImageTag} \
                                            --batch-env ${batchEnv} \
                                            --child-job-entrypoint \"${childJobEnterypoint}\""
        }
    }
}