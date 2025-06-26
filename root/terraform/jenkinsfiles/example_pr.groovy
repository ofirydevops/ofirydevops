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

    stage('Checkout') {
        checkout scm
        sh "ls -l"
    }
    
    stage('Hello World') {
        
        echo("Im the PR test example")
    }
}
