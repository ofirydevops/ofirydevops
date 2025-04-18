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

def gitRepoAddress = "https://github.com/ofiryy/devops-project"

pipelineJob('deploy_github_aws_runners') {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        booleanParam('destroy', false, 'destroy github aws runners')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(gitRepoAddress)
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


pipelineJob('python_remote_dev') {
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
        githubProjectUrl(gitRepoAddress)
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


pipelineJob('python_env_cache_update') {
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
        githubProjectUrl(gitRepoAddress)
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

pipelineJob('python_env_runner') {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        choiceParam('node', nodes, 'Node to run on')

        stringParam('command', 'python data_science/hello_world.py', 'Command to run')

        choiceParam('timeout_in_minutes', 
                     ['10', '20', '40','80'])

        choiceParam('conda_env', 
                    condaEnvs, 
                    'Conda env to run')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(gitRepoAddress)
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
            scriptPath('jenkinsfiles/python_env_runner.groovy')
        }
    }
}

pipelineJob('gh-branch') {
    // triggers {
    //     onBranch {
    //         setPreStatus()
    //         cancelQueued()

    //         mode {
    //             cron()
    //             heavyHooks()
    //             heavyHooksCron()
    //         }

    //         repoProviders {
    //             gitHubPlugin {
    //                 manageHooks(false)
    //                 cacheConnection(false)
    //                 permission { pull() }
    //             }
    //         }

    //         events {

    //             branchRestriction {
    //                 matchCritieria('master')
    //                 matchCritieria('other')
    //             }

    //             commitChecks {
    //                 commitMessagePattern {
    //                     excludeMatching()
    //                     matchCritieria('^(?s)\\[(release|unleash)\\-maven\\-plugin\\].*')
    //                 }
    //             }

    //             created()
    //             hashChanged()
    //             deleted()
    //         }

    //         whitelistedBranches('master')
    //     }

    // }
    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(gitRepoAddress)
    }
   definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url('https://github.com/ofiryy/devops-project.git')
                   credentials('github_access')
                 }
                 branch('update2')
               }
             }
            scriptPath('jenkinsfiles/test.groovy')
        }
    }
}
