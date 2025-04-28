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


// Jenkins DSL api docs link: https://jenkins.ofirydevops.com/plugin/job-dsl/api-viewer/index.html
def gitRepoAddress = "https://github.com/ofiryy/devops-project"

def mainDomain = "ofirydevops.com"

def prReRunPhrasePrefix = "rerun_"

def folders = [
  pull_request_tests : [
    id : "pull_request_tests",
    displayName : "Pull Request Tests"
  ],
  data_science : [
    id : "data_science",
    displayName : "Data Science"
  ],
  infra : [
    id : "infra",
    displayName : "Infra"
  ]
]

def prPipelineConfigs = [
  tf_project_validation : [
    name : "${folders["pull_request_tests"]["id"]}/terraform_projects_validation",
    jenkinsfile : "jenkinsfiles/tf_validation_pr.groovy",
    prContext : "tf_validation"
  ]
]

folders.each { _, config ->

  folder(config["id"]) {
      displayName(config["displayName"])
  }
}

pipelineJob("${folders["infra"]["id"]}/deploy_github_aws_runners") {
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
                   url(gitRepoAddress)
                   credentials('github_access')
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkinsfiles/main.groovy')
        }
    }
}


pipelineJob("${folders["data_science"]["id"]}/python_remote_dev") {
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
                   url(gitRepoAddress)
                   credentials('github_access')
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkinsfiles/remote_development.groovy')
        }
    }
}


pipelineJob("${folders["data_science"]["id"]}/python_env_cache_update") {
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
                   url(gitRepoAddress)
                   credentials('github_access')
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkinsfiles/cache_update.groovy')
        }
    }
}

pipelineJob("${folders["data_science"]["id"]}/python_env_runner") {
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
                   url(gitRepoAddress)
                   credentials('github_access')
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkinsfiles/python_env_runner.groovy')
        }
    }
}


pipelineJob("${folders["infra"]["id"]}/ssl_cert_generator") {
    parameters {
        stringParam('ref', 'update2', 'branch / tag / commit')
        choiceParam('domain', 
                     [
                      "${mainDomain}",
                      "dev.${mainDomain}",
                      "stg.${mainDomain}",
                      "sbx.${mainDomain}"
                      ])
    }

    triggers {
        parameterizedCron {
            parameterizedSpecification('''
            H H 1 * * % domain=ofirydevops.com
            H H 1 * * % domain=dev.ofirydevops.com
            H H 1 * * % domain=stg.ofirydevops.com
            H H 1 * * % domain=sbx.ofirydevops.com
            ''')
        } 
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
                   url(gitRepoAddress)
                   credentials('github_access')
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkinsfiles/ssl_cert_generator.groovy')
        }
    }
}


prPipelineConfigs.each { _, config ->

  def rerunPhrase = "${prReRunPhrasePrefix}${config["prContext"]}"

  pipelineJob(config["name"]) {

    parameters {
      stringParam('rerunPhrase', rerunPhrase)
      stringParam('prContext', config["prContext"])
    }
      properties {
          durabilityHint {
              hint('PERFORMANCE_OPTIMIZED')
          }
          githubProjectUrl(gitRepoAddress)
      }
      triggers {

          githubPullRequests {
              spec('')
              triggerMode('HEAVY_HOOKS')
              events {
                  Open()
                  commentPattern {
                      comment(rerunPhrase)
                  }
                  commitChanged()
                  description {
                      skipMsg('[skip ci]')
                  }
                  cancelQueued(true)
                  preStatus(true) 
                  abortRunning(true)
              }
              repoProviders {
                  githubPlugin {
                      cacheConnection(false)
                      manageHooks(false)
                      repoPermission('ADMIN')
                  }
              }
              branchRestriction {
                  targetBranch('main')
              }
          }
      }
    
      definition {
          cpsScm {
              scm {
                  git {
                      remote {
                          url(gitRepoAddress)
                          credentials('github_access')
                          refspec('+refs/pull/${GITHUB_PR_NUMBER}/merge:refs/remotes/origin-pull/pull/${GITHUB_PR_NUMBER}/merge')
                      }
                      branch('origin-pull/pull/${GITHUB_PR_NUMBER}/merge')
                  }
              }
              scriptPath(config["jenkinsfile"])
        }
      }
    }
}


