pipelineJob('deploy_github_aws_runners') {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        booleanParam('DESTROY', false, 'destroy github aws runners')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
    }

    definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url('https://github.com/ofiryy/devops-project.git')
                   credentials('github_access')
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkinsfiles/main.groovy')
        }
    }
}
