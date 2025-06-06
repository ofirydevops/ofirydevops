def setGhPrStatus(status) {
    def messages = [
        "SUCCESS" : "Passed",
        "PENDING" : "In progress...",
        "FAILURE" : "Failed. For re-run comment: ${env.rerunPhrase}"
    ]

    setGitHubPullRequestStatus state: status, context: env.prContext, message: messages[status]
}

setGhPrStatus("PENDING")

node('basic_arm64_100GB') {
    ansiColor('xterm') {
        try {
           
            main()
            setGhPrStatus("SUCCESS")
        } catch (Exception e) {
            setGhPrStatus("FAILURE")
            throw e
        }
    }
}



def main() {

    def tfProjects = [
        "github_aws_runners" : "github_aws_runners/terraform",
        "root_jenkins" : "root_jenkins/terraform",
        "batch_runner" : "batch_runner/terraform"
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
        sh "cd ${tfProjectPath} && \
            terraform init -backend-config=../../backend.config && \
            terraform validate"
    }
}


