node('basic_arm64_100GB') {
    ansiColor('xterm') {
        try {
            main()
            setGitHubPullRequestStatus state: 'SUCCESS', context: env.JOB_NAME, message: 'Passed'
        } catch (Exception e) {
            setGitHubPullRequestStatus state: 'FAILURE', context: env.JOB_NAME, message: 'Failed'
            throw e
        }
    }
}


def main() {

    def tfProjects = [
        "github_aws_runners" : "github_aws_runners/terraform",
        "root_jenkins" : "root_jenkins/terraform"
    ]
    def jobs = [:]

    stage('Checkout') {
        checkout scm
    }

    stage('Install python libs') {
        sh "pipenv install"
    }
    
    stage('Validate Terraform Projects') {
        
        tfProjects.each { tfProject, path ->
            jobs[tfProject] = getTfProjectValidationJob(path)
        }

        parallel jobs
    }
}

def getTfProjectValidationJob(tfProjectPath) {
    return {
        sh "cd ${tfProjectPath} && terraform init && terraform validate"
    }
}
