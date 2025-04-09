def getDcService(dcServicePrefix, nodeLabel) {
    def dcServiceSuffix = "_amd64"

    def nodeLabelLowerCase = nodeLabel.toLowerCase()
    if (nodeLabelLowerCase.contains("arm64")) {
        dcServiceSuffix = "_arm64"
    }
    if (nodeLabelLowerCase.contains("gpu")) {
        dcServiceSuffix = "${dcServiceSuffix}_gpu"
    }
    def dcService = "${dcServicePrefix}${dcServiceSuffix}"
    return dcService
}

def setUpDockerEnv(pipeline) {
    pipeline.sh("docker buildx create --name ${pipeline.env.DOCKER_CONTAINER_DRIVER_NAME} --driver docker-container --bootstrap")
    pipeline.sh("aws ecr get-login-password --region ${pipeline.env.AWS_REGION} --profile ${pipeline.env.AWS_DEFAULT_PROFILE} | \
                docker login --username AWS --password-stdin ${pipeline.env.AWS_ECR_REGISTRY}")
}

return this
