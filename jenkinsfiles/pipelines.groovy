def condaEnvs = [
  'ofiry',
  'py310_gpu',
  'py310_full',
  'py39_gpu',
  'py39_full',
  'py311_gpu',
  'py312_gpu'
  ]

def nodes = [
  'amd64_4vcpu_16gb_100gb', 
  'arm64_4vcpu_16gb_100gb', 
  'gpu_amd64_4vcpu_16gb_100gb',
  'gpu_arm64_4vcpu_8gb_100gb'
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
        choiceParam('arch', ['amd64', 'arm64'])
        choiceParam('processor', ['cpu', 'gpu'])
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
