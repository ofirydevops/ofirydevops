import argparse
import subprocess
import yaml
from cerberus import Validator
import os
import platform
import boto3
import json
import hashlib
from botocore.exceptions import ClientError
import python_libs.utils as utils


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

DOCKERFILE_PATH= "data_science/docker/Dockerfile"
INPUT_SCHAME_FILE = "data_science/scripts/schemas/py_env_file_schema.yaml"
GLOBAL_CONF_JSON = "global_conf.json"

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--py-env-conf-file',
                             required = True,
                             type     = str,
                             dest     = 'py_env_conf_file')
    args_parser.add_argument('--git-ref',
                             required = True,
                             type     = str,
                             dest     = 'git_ref')
    args_parser.add_argument('--docker-image-tag',
                             required = True,
                             type     = str,
                             dest     = 'docker_image_tag')
    args_parser.add_argument('--target',
                             required = False,
                             default  = "runtime",
                             choices  = ["remote_dev", "runtime"],
                             dest     = 'target')


    args = vars(args_parser.parse_args())
    return args


def image_tag_exists(session, repo_name, tag, region):
    ecr = session.client("ecr", region_name=region)
    try:
        ecr.describe_images(
            repositoryName=repo_name,
            imageIds=[{"imageTag": tag}]
        )
        return True
    except ClientError as e:
        print(f'e.response["Error"]["Code"]: {e.response["Error"]["Code"]}')
        if e.response["Error"]["Code"] == "ImageNotFoundException":
            print("Hllllllo")
            return False
        print("WWaaatttt")
        raise


def yaml_to_dict(file_path):
    try:
        with open(file_path, 'r') as file:
            data = yaml.safe_load(file)
            return data
    except FileNotFoundError:
        print(f"Error: File '{file_path}' not found.")
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file: {e}")
    return {}


def get_system_architecture():
    arch = platform.machine()
    print(f"System Architecture: {arch}")
    return arch


def get_and_validate_py_env_file(py_env_file_path):
    py_env_data = yaml_to_dict(py_env_file_path)
    schema = yaml_to_dict(INPUT_SCHAME_FILE)
    validator = Validator(schema)
    if validator.validate(py_env_data):
        print("Py env validation successful!")
    else:
        print("Validation failed:", validator.errors)
    return py_env_data


def create_conda_env_yaml(conda_env_data):
    conda_env_yaml_file = "conda_env.yaml"
    with open(conda_env_yaml_file, "w") as file:
        yaml.dump(conda_env_data, file)
    os.chmod(conda_env_yaml_file, 0o644)
    return conda_env_yaml_file


def get_cache_image_tag(py_env_conf_file):
    arch               = get_system_architecture()
    py_env_conf        = yaml_to_dict(py_env_conf_file)
    py_env_conf_string = json.dumps(py_env_conf, sort_keys=True)
    arch_config        = json.dumps(CONFIG_BY_ARCH[arch], sort_keys=True)
    with open(DOCKERFILE_PATH, "rb") as file:
        dockerfile_content = file.read()
    hash_obj = hashlib.new("sha256")
    hash_obj.update(py_env_conf_string.encode("utf-8"))
    hash_obj.update(arch_config.encode("utf-8"))
    hash_obj.update(arch.encode("utf-8"))
    hash_obj.update(dockerfile_content)
    return f"hash_{hash_obj.hexdigest()}"


def get_ecr_registry(boto3_session, region):

    sts_client = boto3_session.client("sts")
    response = sts_client.get_caller_identity()
    account_id = response["Account"]
    return f"{account_id}.dkr.ecr.{region}.amazonaws.com"


def get_ecr_repo_address(session, region):
    ecr_registry = get_ecr_registry(session, region)

    ssm = session.client('ssm')
    response = ssm.get_parameter(
        Name='dataScienceCacheRepo'
    )

    repo_name = response['Parameter']['Value']
    return f"{ecr_registry}/{repo_name}"


def build_py_env(args):

    py_env_data = get_and_validate_py_env_file(args["py_env_conf_file"])

    conda_env_yaml_file = create_conda_env_yaml(py_env_data["conda_env_yaml"])

    with open(GLOBAL_CONF_JSON, "r") as file:
        global_conf = json.load(file)

    session = boto3.session.Session(
        region_name = global_conf["region"],
        profile_name = global_conf["profile"]
    )
    arch             = get_system_architecture()
    ecr_repo_address = get_ecr_repo_address(session, global_conf["region"])
    repo_name        = ecr_repo_address.split("/")[1]
    cache_image_tag  = get_cache_image_tag(args["py_env_conf_file"])
    cache_exists     = image_tag_exists(session, repo_name, cache_image_tag, global_conf["region"])

    os.environ["DOCKER_IMAGE_TAG"]          = args["docker_image_tag"]
    os.environ["CONDA_ENV_FILE_PATH"]       = conda_env_yaml_file
    os.environ["COMPOSE_BUILD_TARGET"]      = args["target"]
    os.environ["RUNTIME_IMAGE"]             = py_env_data["base_image"]
    os.environ["CONDA_ENV_CACHE_IMAGE_TAG"] = cache_image_tag
    os.environ["AWS_REGITRY_REF_REPO"]      = ecr_repo_address
    os.environ["AWS_CLI_DOWNLOAD_LINK"]     = CONFIG_BY_ARCH[arch]["AWS_CLI_DOWNLOAD_LINK"]
    os.environ["GIT_REF"]                   = args["git_ref"]

    if cache_exists:
        service = "build_and_read_cache"
    else:
        service = "build_and_write_cache"
    print(f"service: {service}")
    try:
        utils.run_command(f"docker compose -f data_science/docker/docker-compose-v2.yml build {service}")

    finally:
        os.remove(conda_env_yaml_file)


def main():
    args = get_args()
    build_py_env(args)


if __name__ == "__main__":
    main()
