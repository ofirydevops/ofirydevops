import argparse
import subprocess

AWS_GITHUB_EUNNERS_TF_PROJECT = "github_aws_runners/terraform"

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--destroy',
                             action ='store_true',
                             dest   = 'destroy')
    args = vars(args_parser.parse_args())
    return args


def deploy_aws_github_runners(destroy):
    action = "apply"
    if destroy:
        action = "destroy"

    subprocess.run(["terraform", "init"], check=True, cwd=AWS_GITHUB_EUNNERS_TF_PROJECT)
    subprocess.run(["terraform", action, "-auto-approve"], check=True, cwd=AWS_GITHUB_EUNNERS_TF_PROJECT)


def main():
    args = get_args()

    deploy_aws_github_runners(args["destroy"])


if __name__ == "__main__":
    main()

