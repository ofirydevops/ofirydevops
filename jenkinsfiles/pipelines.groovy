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
        choiceParam('node', [
          'amd64_4vcpu_16gb_30gb', 
          'arm64_4vcpu_16gb_30gb', 
          'gpu_amd64_4vcpu_16gb_50gb',
          'gpu_arm64_4vcpu_8gb_50gb'
          ], 
          'Node to run on'
        )
        choiceParam('cuda_image_tag', [
          '12.3.2-cudnn9-runtime-ubuntu22.04', 
          '11.8.0-cudnn8-runtime-ubuntu22.04'
          ], 
          'Image tag for nvidia/cuda base image'
        )
        choiceParam('uptime_in_minutes', 
                     ['10', '20', '40','80'], 
                     'Amount of time to keep the node up')
        choiceParam('conda_env', 
                     ['ofiry'], 
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
