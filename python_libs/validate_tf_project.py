import argparse
import subprocess
import python_libs.utils as utils



def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--path',
                             required = True,
                             type     = str,
                             dest     = 'path')
    args = vars(args_parser.parse_args())
    return args


def validate_tf_project(path):
    
    subprocess.run(["terraform", "init"], cwd=path, check=True)
    subprocess.run(["terraform", "validate"], cwd=path, check=True)



def main():
    args = get_args()
    utils.run_in_decrypted_git_repo(lambda: validate_tf_project(args['path']))


if __name__ == "__main__":
    main()

