// Jenkins DSL api docs link: https://<jenkins-server-address>/plugin/job-dsl/api-viewer/index.html


def condaEnvsV2 = [
  'python_env_runner/conda_envs_v2/ofiry.yaml',
  'python_env_runner/conda_envs_v2/py310_gpu.yaml',
  'python_env_runner/conda_envs_v2/py310_full.yaml'
]

def nodes = [
  'basic_amd64_100GB', 
  'basic_arm64_100GB', 
  'gpu_amd64_100GB',
  ]



def ofirydevopsGithubUrl = "https://github.com/ofirydevops/ofirydevops.git"

def exampleGithubRepoUrl             = binding.variables['example_github_repo_url']
def exampleGithubRepoName            = binding.variables['example_github_repo_name']
def exampleGithubRepoJenkinsfilePath = binding.variables['example_github_jenkinsfile_path']


def prReRunPhrasePrefix = "rerun_"

def folders = [
  examples: [
    id : "examples",
    displayName : "${exampleGithubRepoName} Examples"
  ],
  python_env_runner : [
    id : "python_env_runner",
    displayName : "Python Env Builder"
  ],
  infra : [
    id : "infra",
    displayName : "Infra"
  ],
  batch_runner : [
    id : "batch_runner",
    displayName : "Batch Runner"
  ]
]

def prPipelineConfigs = [
  pr_test_example : [
    name : "${folders["examples"]["id"]}/${exampleGithubRepoName}_pr_test_example",
    jenkinsfile : exampleGithubRepoJenkinsfilePath,
    prContext : "${exampleGithubRepoName}_pr_test_example",
    githubRepoUrl: exampleGithubRepoUrl
  ]
]

folders.each { _, config ->

  folder(config["id"]) {
      displayName(config["displayName"])
  }
}


prPipelineConfigs.each { _, config ->

  def rerunPhrase = "${prReRunPhrasePrefix}${config["prContext"]}"

  pipelineJob(config["name"]) {

      environmentVariables {
        envs([
          "rerunPhrase" : rerunPhrase,
          "prContext"   : config["prContext"]
        ])
      }
  
      properties {
          durabilityHint {
              hint('PERFORMANCE_OPTIMIZED')
          }
          githubProjectUrl(config["githubRepoUrl"])
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
                          url(config["githubRepoUrl"])
                          credentials("jenkins_gh_app")
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


pipelineJob("${folders["infra"]["id"]}/ssl_cert_generator") {
    parameters {
        stringParam('ref', 'update2', 'branch / tag / commit')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(ofirydevopsGithubUrl)
    }
    definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url(ofirydevopsGithubUrl)
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkins/jenkinsfiles/ssl_cert_generator.groovy')
        }
    }
}


pipelineJob("${folders["batch_runner"]["id"]}/test_batch_runner") {
    parameters {
        stringParam('ref', 'update2', 'branch / tag / commit')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(ofirydevopsGithubUrl)
    }
    definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url(ofirydevopsGithubUrl)
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkins/jenkinsfiles/test_batch_runner.groovy')
        }
    }
}


pipelineJob("${folders["python_env_runner"]["id"]}/python_env_runner") {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        choiceParam('node', nodes, 'Node to run on')

        stringParam('command', 'python python_env_runner/hello_world.py', 'Command to run')

        choiceParam('timeout_in_minutes', 
                     ['10', '20', '40','80'])

        choiceParam('py_env_conf_file', 
                    condaEnvsV2, 
                    'Python env to run')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(ofirydevopsGithubUrl)
    }

    definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url(ofirydevopsGithubUrl)
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkins/jenkinsfiles/python_env_runner.groovy')
        }
    }
}

pipelineJob("${folders["python_env_runner"]["id"]}/python_remote_dev") {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')
        stringParam('git_user_email', '', 'Email of user with which you want to access git')
        choiceParam('node', nodes, 'Node to run on')

        choiceParam('uptime_in_minutes', 
                     ['10', '20', '40','80'], 
                     'Amount of time to keep the node up')

        choiceParam('py_env_conf_file', 
                    condaEnvsV2, 
                    'Python env to run')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(ofirydevopsGithubUrl)
    }

    definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url(ofirydevopsGithubUrl)
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkins/jenkinsfiles/python_env_remote_dev.groovy')
        }
    }
}


pipelineJob("${folders["python_env_runner"]["id"]}/python_env_batch_runner") {
    parameters {
        stringParam('ref', 'update2', 'branch / tag / commit')

        stringParam('child_job_entrypoint', 'python -m python_env_runner.batch_test.child', 'Command to run')

        stashedFile {
            name('py_env_conf.yaml')
            description('Python env conf file')
        }

        stashedFile {
            name('child_jobs_input.yaml')
            description('File with inputs of all child jobs')
        }

        choiceParam('batch_env', 
                    ["main_arm64", "main_amd64", "gpu_amd64"], 
                    'Batch env to use')

    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(ofirydevopsGithubUrl)
    }

    definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url(ofirydevopsGithubUrl)
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkins/jenkinsfiles/python_env_batch_runner.groovy')
        }
    }
}


pipelineJob("${folders["infra"]["id"]}/manage_tf_infra") {
    parameters {
        stringParam('ref', 'main', 'branch / tag / commit')

        choiceParam('tf_project', 
                     [ 
                      'jenkins', 
                      'github_actions', 
                      'codeartifact',
                      'batch_runner',
                      'python_env_runner'
                      ], 
                     'The Terraform project')

        choiceParam('tf_action', 
                    [
                      'apply',
                      'destroy',
                      'plan',
                      'validate'
                    ], 
                    'Terraform action to run')
    }

    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(ofirydevopsGithubUrl)
    }

    definition {
           cpsScm {
             scm {
               git {
                 remote {
                   url(ofirydevopsGithubUrl)
                 }
                 branch('${ref}')
               }
             }
            scriptPath('jenkins/jenkinsfiles/manage_tf_project.groovy')
        }
    }
}
