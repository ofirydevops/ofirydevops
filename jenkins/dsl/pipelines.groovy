// Jenkins DSL api docs link: https://<jenkins-server-address>/plugin/job-dsl/api-viewer/index.html

import groovy.json.JsonSlurper

def dslConfigJsonFile              = binding.variables['dsl_config_json_file']
def dslConfig                      = new JsonSlurper().parse(new File(dslConfigJsonFile))
def nodes                          = dslConfig["nodes"]
def tfProjects                     = dslConfig["tf_projects"]
def tfActions                      = dslConfig["tf_actions"]
def amiConfs                       = dslConfig["ami_confs"]
def batchEnvs                      = dslConfig["batch_envs"]
def ofirydevopsRef                 = dslConfig["ofirydevops_ref"]
def generatedGithubRepoUrl         = dslConfig["generated_gh_repo_url"]
def generatedGithubRepoName        = dslConfig["generated_gh_repo_name"]
def generatedGithubRepoJenkinsfile = dslConfig["generated_gh_repo_pr_jenkinsfile"]
def githubAppCredsId               = dslConfig["github_jenkins_app_creds_id"]
def pyEnvConfFileDefault           = dslConfig["py_env_conf_file_default"]
def pyEnvJobRunnerDefaultCmd       = dslConfig["py_env_job_runner_default_cmd"]
def defaultAuthorizedKeysFile      = dslConfig["default_authorized_keys_file"]
def repositories                   = dslConfig["repositories"]

def prReRunPhrasePrefix            = "rerun_"
def timeoutInMinutesOptions        = ['10', '20', '40','80']
def ofirydevopsGithubUrl           = "https://github.com/ofirydevops/ofirydevops.git"
def jenkisnfiles                   = [
  ssl_cert_generator :      'jenkins/jenkinsfiles/ssl_cert_generator.groovy',
  batch_runner_test :       'jenkins/jenkinsfiles/batch_runner_test.groovy',
  python_env_job_runner :   'jenkins/jenkinsfiles/python_env_job_runner.groovy',
  python_env_remote_dev :   'jenkins/jenkinsfiles/python_env_remote_dev.groovy',
  terraform_projects_mgmt : 'jenkins/jenkinsfiles/terraform_projects_mgmt.groovy',
  python_env_batch_runner : 'jenkins/jenkinsfiles/python_env_batch_runner.groovy',
  ami_generator :           'jenkins/jenkinsfiles/ami_generator.groovy'
]



def folders = [
  examples: [
    id : "examples",
    displayName : "${generatedGithubRepoName}"
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
    name : "${folders["examples"]["id"]}/${generatedGithubRepoName}_pr_test_example",
    jenkinsfile : generatedGithubRepoJenkinsfile,
    prContext : "${generatedGithubRepoName}_pr_test_example",
    githubRepoUrl: generatedGithubRepoUrl
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
                          credentials(githubAppCredsId)
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
        stringParam('ref', ofirydevopsRef, 'Branch / Tag / Commit')
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
            scriptPath(jenkisnfiles["ssl_cert_generator"])
        }
    }
}


pipelineJob("${folders["batch_runner"]["id"]}/batch_runner_test") {
    parameters {
        stringParam('ref', ofirydevopsRef, 'Branch / Tag / Commit')
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
            scriptPath(jenkisnfiles["batch_runner_test"])
        }
    }
}


pipelineJob("${folders["python_env_runner"]["id"]}/python_env_job_runner") {
    parameters {
        stringParam('ofirydevops_ref',    ofirydevopsRef,           'Branch / Tag / Commit')
        choiceParam('repository',         repositories,             'Repository to work with')
        stringParam('repository_ref',     'main',                   'Branch / Tag / Commit')
        choiceParam('credentials_id',     [githubAppCredsId])
        stringParam('py_env_conf_file',   pyEnvConfFileDefault,     'Python environment file path')
        stringParam('command',            pyEnvJobRunnerDefaultCmd, 'Run command')
        choiceParam('timeout_in_minutes', timeoutInMinutesOptions,  'Job timeout in minutes')
        choiceParam('node',               nodes,                    'Runner node')
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
                 branch('${ofirydevops_ref}')
               }
             }
            scriptPath(jenkisnfiles["python_env_job_runner"])
        }
    }
}

pipelineJob("${folders["python_env_runner"]["id"]}/python_env_remote_dev") {
    parameters {
        stringParam('ofirydevops_ref',      ofirydevopsRef,            'Branch / Tag / Commit')
        choiceParam('repository',           repositories,              'Repository to work with')
        stringParam('repository_ref',       'main',                    'Branch / Tag / Commit')
        choiceParam('credentials_id',       [githubAppCredsId])
        stringParam('py_env_conf_file',     pyEnvConfFileDefault,      'Python environment file path')
        stringParam('authorized_keys_file', defaultAuthorizedKeysFile, 'File containing the public ssh that will have access to the remote machine')
        stringParam('git_user_email',       '',                        'Email of user with which you want to access git (Optional)')
        choiceParam('uptime_in_minutes',    timeoutInMinutesOptions,   'Runner node uptime in minutes')
        choiceParam('node',                 nodes,                     'Runner node')
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
                 branch('${ofirydevops_ref}')
               }
             }
            scriptPath(jenkisnfiles["python_env_remote_dev"])
        }
    }
}


pipelineJob("${folders["python_env_runner"]["id"]}/python_env_batch_runner") {
    parameters {
        stringParam('ref',                  ofirydevopsRef,                                 'Branch / Tag / Commit')
        stringParam('child_job_entrypoint', 'python -m python_env_runner.batch_test.child', 'Command to run')
        choiceParam('batch_env',            batchEnvs,                                      'Batch env to use')

        stashedFile { 
          name('py_env_conf.yaml')      
          description('Python env conf file') 
        }
        stashedFile { 
          name('child_jobs_input.yaml') 
          description('File with inputs of all child jobs') 
        }

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
            scriptPath(jenkisnfiles["python_env_batch_runner"])
        }
    }
}


pipelineJob("${folders["infra"]["id"]}/terraform_projects_mgmt") {
    parameters {
        stringParam('ref',        ofirydevopsRef, 'Branch / Tag / Commit')
        choiceParam('tf_project', tfProjects,     'The Terraform project')
        choiceParam('tf_action',  tfActions,      'Terraform action to run')
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
            scriptPath(jenkisnfiles["terraform_projects_mgmt"])
        }
    }
}


pipelineJob("${folders["infra"]["id"]}/ami_generator") {
    parameters {
        stringParam('ref',      ofirydevopsRef, 'Branch / Tag / Commit')
        choiceParam('ami_conf', amiConfs,     'The AMI conf to generate')
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
            scriptPath(jenkisnfiles["ami_generator"])
        }
    }
}


