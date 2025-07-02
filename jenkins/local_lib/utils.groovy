

def setupGlobalConf(pipeline) {
    def config = [
        region: pipeline.env.MAIN_AWS_REGION,
        profile: pipeline.env.MAIN_AWS_PROFILE,
        namespace: pipeline.env.NAMESPACE
    ]

    pipeline.writeYaml file: 'pylib/ofirydevops/global_conf.yaml', data: config, overwrite: true
}

return this