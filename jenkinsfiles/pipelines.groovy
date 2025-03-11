pipelineJob('main') {
    parameters {
        stringParam('ref', 'update', 'branch / tag / commit')
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
                 branch('update')
               }
             }
            scriptPath('jenkinsfiles/main.groovy')
        }
    }
}
