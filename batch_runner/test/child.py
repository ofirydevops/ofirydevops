import argparse
import json
from pprint import pprint
import os
import subprocess

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--input-path',
                             required = True,
                             type     = str,
                             dest     = 'input_path')

    args = vars(args_parser.parse_args())
    return args


def main():
    args = get_args()
    print(f'args["input_path"]: {args["input_path"]}')

    with open(args["input_path"], 'r') as f:
        data = json.load(f)

    pprint(data)

    print(f'CHILDJOB_BATCH_RUN_ID: {os.environ["CHILDJOB_BATCH_RUN_ID"]}')
    print(f'CHILDJOB_VOLUME_PATH: {os.environ["CHILDJOB_VOLUME_PATH"]}')
    print(f'CHILDJOB_INPUT_PATH: {os.environ["CHILDJOB_INPUT_PATH"]}')

    subprocess.run("docker pull nginx", check = True, shell = True)




if __name__ == "__main__":
    main()

