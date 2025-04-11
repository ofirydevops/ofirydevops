import json
from os.path import dirname
import os
import subprocess
import uuid
import boto3
import yaml
import base64

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
        subprocess.run(["git-crypt", "unlock", gitcrypt_key_file_name], check=False)
    finally:
        os.remove(gitcrypt_key_file_name)


def encrypt_git_repo():
    subprocess.run(["git-crypt", "lock"], check=False)


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


