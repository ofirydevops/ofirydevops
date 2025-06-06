import argparse
import subprocess
import os
import python_libs.utils as utils
import json
import data_science.scripts.cnfg as cnfg
import boto3

GLOBAL_CONF_JSON = "global_conf.json"

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--docker-image-tag',
                             required = True,
                             type     = str,
                             dest     = 'docker_image_tag')
    args_parser.add_argument('--docker-image-repo',
                             required = False,
                             type     = str,
                             default  = cnfg.DEFAULT_DOCKER_IMAGE_REPO,
                             dest     = 'docker_image_repo')
    args_parser.add_argument('--entrypoint',
                             required = False,
                             default  = "top",
                             type     = str,
                             dest     = 'entrypoint')
    args_parser.add_argument('--remote-dev',
                             action = 'store_true',
                             dest   = 'remote_dev')



    args = vars(args_parser.parse_args())
    return args


def get_ecr_registry():
    with open(cnfg.GLOBAL_CONF_JSON, "r") as file:
        global_conf = json.load(file)

    session = boto3.session.Session(
        region_name  = global_conf["region"],
        profile_name = global_conf["profile"]
    )

    ecr_registry = utils.get_ecr_registry(session, global_conf["region"])

    return ecr_registry


def check_nvidia_gpu():
    try:
        result = subprocess.run(
            ["nvidia-smi"],
            capture_output=True,
            text=True,
            shell=True,
            check=False  # Don't raise an exception on failure
        )

        if result.returncode == 0 and "NVIDIA-SMI" in result.stdout:
            print("NVIDIA GPU found!")
            print(result.stdout)  # Optional: Print full output for details
            return True
        else:
            print("No NVIDIA GPU found or nvidia-smi not available.")
            return False
    except (subprocess.SubprocessError, FileNotFoundError):
        print("No NVIDIA GPU found or nvidia-smi not installed.")
        return False


def run_py_env(args):

    print(json.dumps(args))

    if args["remote_dev"]:
        flags = "--service-ports"
    else:
        flags = ""

    if check_nvidia_gpu():
        service = "run_with_gpu"
    else:
        service = "run_with_no_gpu"

    os.environ["DOCKER_IMAGE_TAG"]  = args.get("docker_image_tag", cnfg.DEFAULT_DOCKER_IMAGE_TAG)
    os.environ["DOCKER_IMAGE_REPO"] = args.get("docker_image_repo", cnfg.DEFAULT_DOCKER_IMAGE_REPO)
    os.environ["DOCKER_REGISTRY"]   = get_ecr_registry()
    os.environ["ENTRYPOINT"]        = args["entrypoint"]

    utils.run_shell_cmd_without_buffering(f"docker compose -f {cnfg.DOCKER_COMPOSE_FILE} run {flags} {service}")


def main():
    args = get_args()
    run_py_env(args)


if __name__ == "__main__":
    main()
