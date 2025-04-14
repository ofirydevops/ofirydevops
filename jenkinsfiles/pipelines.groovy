def condaEnvs = [
  'ofiry',
  'py310_gpu',
  'py310_full'
  ]

def nodes = [
  'basic_amd64_100GB', 
  'basic_arm64_100GB', 
  'gpu_amd64_100GB',
  'gpu_arm64_100GB'
  ]

pipelineJob('deploy_github_aws_runners') {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        booleanParam('destroy', false, 'destroy github aws runners')
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


pipelineJob('data_science_remote_development') {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        choiceParam('node', nodes, 'Node to run on')

        choiceParam('uptime_in_minutes', 
                     ['10', '20', '40','80'], 
                     'Amount of time to keep the node up')

        choiceParam('conda_env', 
                    condaEnvs, 
                    'Conda env to run')
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
            scriptPath('jenkinsfiles/remote_development.groovy')
        }
    }
}


pipelineJob('data_science_update_cahce') {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        
        choiceParam('node', 
        [
        'basic_amd64_100GB',
        'basic_arm64_100GB'
        ])
        booleanParam('gpu', false)
        choiceParam('conda_env', 
                    condaEnvs, 
                    'Conda env for which the cache will be updated')
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
            scriptPath('jenkinsfiles/cache_update.groovy')
        }
    }
}
