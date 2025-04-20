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


pipelineJob('terraform_projects_validation') {
    properties {
        durabilityHint {
            hint('PERFORMANCE_OPTIMIZED')
        }
        githubProjectUrl(gitRepoAddress)
    }
    triggers {
        ghprbTrigger {
          useGitHubHooks(true)
          triggerPhrase('retest terraform_projects_validation')
          permitAll(true)
          skipBuildPhrase('')
          displayBuildErrorsOnDownstreamBuilds(true)
          buildDescTemplate('PR #$pullId $abbrTitle url: $url')
          commitStatusContext('')
          whiteListTargetBranches {
              ghprbBranch {
                  branch('main')
              }
          } 
          extensions {
            ghprbCancelBuildsOnUpdate {
                overrideGlobal(true)
            }
            ghprbSimpleStatus {
                commitStatusContext('$JOB_NAME')
                showMatrixStatus(false)
                statusUrl('')
                triggeredStatus('')
                startedStatus('')
                addTestResults(true)
            } 
          }

          adminlist('')
          whitelist('')
          orgslist('')
          cron('')
          onlyTriggerPhrase(false) 
          autoCloseFailedPullRequests(false)
          commentFilePath('')
          blackListCommitAuthor('') 
          allowMembersOfWhitelistedOrgsAsAdmin(false) 
          msgSuccess('')
          msgFailure('') 
          gitHubAuthId('') 
          blackListLabels('') 
          whiteListLabels('')
          includedRegions('')
          excludedRegions('')

        }


        // githubPullRequests {
        //     spec('')
        //     triggerMode('HEAVY_HOOKS')
        //     events {
        //         Open()
        //         commentPattern {
        //             comment('retest terraform_projects_validation')
        //         }
        //         commitChanged()
        //         description {
        //             skipMsg('[skip ci]')
        //         }
        //         cancelQueued(true)
        //         preStatus(true) 
        //         abortRunning(true)
        //     }
        //     repoProviders {
        //         githubPlugin {
        //             cacheConnection(false)
        //             manageHooks(false)
        //             repoPermission('ADMIN')
        //         }
        //     }
        //     branchRestriction {
        //         targetBranch('main')
        //     } 
        // }


    }
  
    definition {
        cpsScm {
            scm {
                git {
                    remote {
                        url('https://github.com/ofiryy/devops-project.git')
                        credentials('github_access')
                        // refspec('+refs/pull/${GITHUB_PR_NUMBER}/merge:refs/remotes/origin-pull/pull/${GITHUB_PR_NUMBER}/merge')
                        refspec('+refs/heads/*:refs/remotes/origin/* +refs/pull/${ghprbPullId}/*:refs/remotes/origin/pr/${ghprbPullId}/*')
                    }
                    // branch('origin-pull/pull/${GITHUB_PR_NUMBER}/merge')
                    branch('${sha1}')
                }
            }
            scriptPath('jenkinsfiles/test.groovy')
      }
    }
}



