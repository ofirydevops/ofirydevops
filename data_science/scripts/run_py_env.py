import argparse
import subprocess
import os
import python_libs.utils as utils


GLOBAL_CONF_JSON = "global_conf.json"

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--docker-image-tag',
                             required = True,
                             type     = str,
                             dest     = 'docker_image_tag')
    args_parser.add_argument('--cmd',
                             required = False,
                             default  = "",
                             type     = str,
                             dest     = 'cmd')
    args_parser.add_argument('--remote-dev',
                             action = 'store_true',
                             dest   = 'remote_dev')



    args = vars(args_parser.parse_args())
    return args


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

    if args["remote_dev"]:
        flags = "--service-ports"
    else:
        flags = ""

    if check_nvidia_gpu():
        service = "run_with_gpu"
    else:
        service = "run_with_no_gpu"

    os.environ["DOCKER_IMAGE_TAG"] = args["docker_image_tag"]
    command = args["cmd"]
    utils.run_command(f"docker compose -f data_science/docker/docker-compose-v2.yml run {flags} {service} {command}")


def main():
    args = get_args()
    run_py_env(args)


if __name__ == "__main__":
    main()
