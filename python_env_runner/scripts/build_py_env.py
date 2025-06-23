import argparse
import yaml
from cerberus import Validator
import os
import platform
import json
import hashlib
import re
import subprocess
from botocore.exceptions import ClientError

from pylib.ofirydevops.utils import main as utils
import python_env_runner.scripts.cnfg as cnfg


def validate_email(email):
    email_pattern = r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$"
    if not re.match(email_pattern, email):
        raise argparse.ArgumentTypeError(
            f"'{email}' is not a valid email address. Must match pattern: {email_pattern}"
        )
    return email
class email_action(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        if values is None:
            setattr(namespace, self.dest, parser.get_default(self.dest))
        else:
            validated_email = validate_email(values)
            setattr(namespace, self.dest, validated_email)

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--py-env-conf-file',
                             required = True,
                             type     = str,
                             dest     = 'py_env_conf_file')
    args_parser.add_argument('--docker-image-tag',
                             required = True,
                             type     = str,
                             dest     = 'docker_image_tag')
    args_parser.add_argument('--docker-image-repo',
                             required = False,
                             type     = str,
                             default  = cnfg.DEFAULT_DOCKER_IMAGE_REPO,
                             dest     = 'docker_image_repo')
    args_parser.add_argument('--git-ref',
                             required = False,
                             type     = str,
                             default  = 'main',
                             dest     = 'git_ref')
    args_parser.add_argument('--target',
                             required = False,
                             default  = "runtime",
                             choices  = ["remote_dev", "runtime"],
                             dest     = 'target')
    args_parser.add_argument('--git-user-email',
                             nargs    = "?",
                             action   = email_action,
                             default  = "@",
                             required = False,
                             help     = "Git user email address (e.g., user@example.com). Defaults to '@'.")


    args = vars(args_parser.parse_args())
    return args


def image_tag_exists(session, repo_name, tag, region):
    ecr = session.client("ecr", region_name=region)
    try:
        ecr.describe_images(
            repositoryName=repo_name,
            imageIds=[{ "imageTag": tag }]
        )
        return True
    except ClientError as e:
        if e.response["Error"]["Code"] == "ImageNotFoundException":
            return False
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


def get_system_arch():
    arch = platform.machine()
    return arch


def get_and_validate_py_env_file(py_env_file_path):
    py_env_data = yaml_to_dict(py_env_file_path)
    schema = yaml_to_dict(cnfg.INPUT_SCHAME_FILE)
    validator = Validator(schema)
    if validator.validate(py_env_data):
        print("Py env validation successful!")
    else:
        print("Validation failed:", validator.errors)
    return validator.normalized(py_env_data)


def create_conda_env_yaml(conda_env_data):
    conda_env_yaml_file = "conda_env.yaml"
    with open(conda_env_yaml_file, "w") as file:
        yaml.dump(conda_env_data, file)
    os.chmod(conda_env_yaml_file, cnfg.FILE_PERMISSIONS)
    return conda_env_yaml_file


def get_cache_image_tag(py_env_conf_file, cache_image_tag_prefix):
    arch               = get_system_arch()
    py_env_conf        = yaml_to_dict(py_env_conf_file)
    py_env_conf_string = json.dumps(py_env_conf, sort_keys=True)
    arch_config_string = json.dumps(cnfg.CONFIG_BY_ARCH[arch], sort_keys=True)

    with open(cnfg.DOCKERFILE_PATH, "rb") as file:
        dockerfile_content = file.read()

    hash_obj = hashlib.new("sha256")
    hash_obj.update(py_env_conf_string.encode("utf-8"))
    hash_obj.update(arch_config_string.encode("utf-8"))
    hash_obj.update(arch.encode("utf-8"))
    hash_obj.update(dockerfile_content)

    return f"{cache_image_tag_prefix}{hash_obj.hexdigest()[:20]}"


def get_cache_ecr_repo_address(session, region, namespace):
    ecr_registry = utils.get_ecr_registry(session, region)

    ssm = session.client('ssm')
    response = ssm.get_parameter(
        Name = cnfg.ECR_CACHE_REPO_SSM_PARAM.format(namespace)
    )

    repo_name = response['Parameter']['Value']
    return f"{ecr_registry}/{repo_name}"


def set_dockerfile_permissions():
    os.chmod(cnfg.DOCKERFILE_PATH, cnfg.FILE_PERMISSIONS)


def build_py_env(args):

    print(json.dumps(args, indent=4))

    py_env_data = get_and_validate_py_env_file(args["py_env_conf_file"])

    conda_env_yaml_file = create_conda_env_yaml(py_env_data["conda_env_yaml"])

    profile, region  = utils.get_profile_and_region()
    session          = utils.get_boto3_session()
    namespace        = utils.get_namespace()
    arch             = get_system_arch()
    ecr_repo_address = get_cache_ecr_repo_address(session, region, namespace)
    cache_repo_name  = ecr_repo_address.split("/")[1]
    ecr_registry     = ecr_repo_address.split("/")[0]

    cache_image_tag_prefix = utils.get_ssm_param(cnfg.CACHE_IMAGE_TAG_PREFIX_SSM_PARAM.format(namespace))
    cache_image_tag        = get_cache_image_tag(args["py_env_conf_file"], cache_image_tag_prefix)
    set_dockerfile_permissions()
    
    
    cache_exists     = image_tag_exists(session, 
                                        cache_repo_name, 
                                        cache_image_tag, 
                                        region)
    
    print(f"cache_image_tag: {cache_image_tag}, cache_exists: {cache_exists}")

    os.environ["DOCKER_IMAGE_TAG"]          = args.get("docker_image_tag", cnfg.DEFAULT_DOCKER_IMAGE_TAG)
    os.environ["DOCKER_IMAGE_REPO"]         = args.get("docker_image_repo", cnfg.DEFAULT_DOCKER_IMAGE_REPO)
    os.environ["DOCKER_REGISTRY"]           = ecr_registry

    os.environ["CONDA_ENV_FILE_PATH"]       = conda_env_yaml_file
    os.environ["COMPOSE_BUILD_TARGET"]      = args.get("target", "runtime")
    os.environ["RUNTIME_IMAGE"]             = py_env_data["base_image"]
    os.environ["CONDA_ENV_CACHE_IMAGE_TAG"] = cache_image_tag
    os.environ["AWS_REGITRY_REF_REPO"]      = ecr_repo_address
    os.environ["AWS_CLI_DOWNLOAD_LINK"]     = cnfg.CONFIG_BY_ARCH[arch]["AWS_CLI_DOWNLOAD_LINK"]
    os.environ["GIT_REF"]                   = args.get("git_ref", "main")
    os.environ["GIT_USER_EMAIL"]            = args.get("git_user_email", "@")


    if cache_exists:
        service = "build_and_read_cache"
    else:
        service = "build_and_write_cache"

    try:
        utils.auth_ecr(region      = region, 
                       profile     = profile, 
                       ecr_registry= ecr_registry)

        utils.run_shell_cmd_without_buffering(f"docker compose -f {cnfg.DOCKER_COMPOSE_FILE} build {service}")
        result = subprocess.run(
            f"docker compose -f {cnfg.DOCKER_COMPOSE_FILE} config --format json",
            capture_output = True,
            text           = True,
            check          = True,
            shell          = True
        )

        
        docker_compose_config = json.loads(result.stdout)

        print(json.dumps(docker_compose_config, indent=4))
        
        image_url = docker_compose_config["services"][service]["image"]
        
        return image_url
    finally:
        os.remove(conda_env_yaml_file)


def main():
    args = get_args()
    build_py_env(args)


if __name__ == "__main__":
    main()
