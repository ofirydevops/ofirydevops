DEFAULT_DOCKER_REGISTRY          = "local"
DEFAULT_DOCKER_IMAGE_REPO        = "python-env"
DEFAULT_DOCKER_IMAGE_TAG         = "local"
DOCKER_COMPOSE_FILE              = "python_env_runner/docker/docker-compose.yml"
ECR_CACHE_REPO_SSM_PARAM         = "/{}/ecr_repo/python_env_docker_cache"
CACHE_IMAGE_TAG_PREFIX_SSM_PARAM = "/{}/python_env_runner/cache_image_prefix"
DOCKERFILE_PATH                  = "python_env_runner/docker/Dockerfile"
INPUT_SCHAME_FILE                = "python_env_runner/scripts/schemas/py_env_file_schema.yaml"
FILE_PERMISSIONS                 = 0o644

CONFIG_BY_ARCH = {
    "arm64" : {
        "AWS_CLI_DOWNLOAD_LINK" : "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-2.15.37.zip",
        "MICROMAMBA_DOWNLOAD_LINK" : "https://micro.mamba.pm/api/micromamba/linux-aarch64/2.1.0",
    },
    "aarch64" : {
        "AWS_CLI_DOWNLOAD_LINK" : "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-2.15.37.zip",
        "MICROMAMBA_DOWNLOAD_LINK" : "https://micro.mamba.pm/api/micromamba/linux-aarch64/2.1.0"

    },
    "x86_64" : {
        "AWS_CLI_DOWNLOAD_LINK" : "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.15.37.zip",
        "MICROMAMBA_DOWNLOAD_LINK" : "https://micro.mamba.pm/api/micromamba/linux-64/2.1.0"
    }
}

