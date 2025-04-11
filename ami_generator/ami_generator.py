import argparse
import json
from os.path import dirname
import os
import subprocess
import uuid
import boto3
import datetime
<<<<<<< HEAD
import yaml
import base64

PACKER_CONF_FILE = "ami_generator/main_conf.yaml"
AWS_SM_SECRET_NAME = "general_secrets"
GITCRYPT_KEY_SECRET_NAME = "DEVOPS_PROJECT_GITCRYPT_KEY"


def decrypt_git_repo():
    session = boto3.session.Session(
        region_name = "eu-central-1",
        profile_name = "OFIRYDEVOPS"
    )
    sm = session.client('secretsmanager')
    response = sm.get_secret_value(SecretId = AWS_SM_SECRET_NAME)
    secret_string = response["SecretString"]
    gitcrypt_key_base64 = json.loads(secret_string)[GITCRYPT_KEY_SECRET_NAME]
    gitcrypt_key = base64.b64decode(gitcrypt_key_base64)
    gitcrypt_key_file_name = str(uuid.uuid4())
    with open(gitcrypt_key_file_name, 'wb') as gitcrypt_key_file:
        gitcrypt_key_file.write(gitcrypt_key)
    try:
        subprocess.run(["git-crypt", "unlock", gitcrypt_key_file_name], check=True)
    finally:
        os.remove(gitcrypt_key_file_name)


def encrypt_git_repo():
    subprocess.run(["git-crypt", "lock"], check=True)


def run_in_decrypted_git_repo(func_to_run):

    decrypt_git_repo()

    try:
        func_to_run()
    
    finally:
        encrypt_git_repo()


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
=======
import python_libs.utils as utils



PACKER_CONF_FILE = "ami_generator/main_conf.yaml"
>>>>>>> update2

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--conf',
                             required = True,
<<<<<<< HEAD
                             choices  = yaml_to_dict(PACKER_CONF_FILE).keys(),
=======
                             choices  = utils.yaml_to_dict(PACKER_CONF_FILE).keys(),
>>>>>>> update2
                             dest     = 'conf')
    args = vars(args_parser.parse_args())
    return args

def get_formatted_timestamp():
    timestamp = datetime.datetime.now().timestamp()
    formatted_timestamp = datetime.datetime.fromtimestamp(timestamp).strftime("%d_%m_%Y__%H_%M")
    return formatted_timestamp


def run_packer(input_dict):
    packer_input_file_name = f'{uuid.uuid4()}.json'

    with open(packer_input_file_name, "w") as packer_input_file:
        packer_input_file.write(json.dumps(input_dict))
    
    subprocess.run(["packer", "init", dirname(input_dict["packer_hcl_path"])], check=True)
    subprocess.run(["packer", "build", f"-var-file={packer_input_file_name}", input_dict["packer_hcl_path"]], check=True)
    os.remove(packer_input_file_name)


def store_ami_ids_in_ssm(input_dict):
    session = boto3.session.Session(
        region_name = "eu-central-1",
        profile_name = "OFIRYDEVOPS"
    )
    ec2 = session.client('ec2')
    ssm = session.client('ssm')

    for ami_conf in input_dict["images"].values():
        if "ami_id_ssm_key" not in ami_conf:
            continue

        response = ec2.describe_images(
            Filters = [
                {
                    'Name' : 'name',
                    'Values' : [ami_conf["ami_name"]]
                }
            ]
        )

        ami_id = response["Images"][0]["ImageId"]

        ssm.put_parameter(
            Name = ami_conf["ami_id_ssm_key"],
            Value = ami_id,
            Type = 'String',
            Overwrite = True
        )


def main():
    args = get_args()
<<<<<<< HEAD
    input_dict = yaml_to_dict(PACKER_CONF_FILE)[args["conf"]]
=======
    input_dict = utils.yaml_to_dict(PACKER_CONF_FILE)[args["conf"]]

    print(json.dumps(input_dict, indent=4))
>>>>>>> update2

    timestamp = get_formatted_timestamp()

    for ami in input_dict["images"]:
        input_dict["images"][ami]["ami_name"] = f'PACKER_{ami}__{timestamp}'

<<<<<<< HEAD


    run_in_decrypted_git_repo(lambda: run_packer(input_dict))
=======
    utils.run_in_decrypted_git_repo(lambda: run_packer(input_dict))
>>>>>>> update2

    store_ami_ids_in_ssm(input_dict)


if __name__ == "__main__":
    main()

