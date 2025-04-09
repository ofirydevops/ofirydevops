def getDcService(dcServicePrefix, nodeLabel) {
    def dcServiceSuffix = "_amd64"

    def nodeLabelLowerCase = nodeLabel.toLowerCase()
    if (nodeLabelLowerCase.contains("arm64")) {
        dcServiceSuffix = "arm64"
    }
    if (nodeLabelLowerCase.contains("gpu")) {
        dcServiceSuffix = "${serviceSuffix}_gpu"
    }
    def dcService = "${dcServicePrefix}${dcServiceSuffix}"
    return dcService
}

return this