import json
import os
import subprocess
import uuid
import boto3
import yaml
import base64
import selectors
import sys
import string
import random
from importlib import resources
from pathlib import Path
from cerberus import Validator

GLOBAL_CONF_SCEHMA = {
    "region": {
        "type": "string",
        "required": True,
        "empty": False
    },
    "profile": {
        "type": "string",
        "required": True,
        "empty": False
    },
    "namespace": {
        "type": "string",
        "required": True,
        "regex": "^[a-z][a-z0-9]{0,6}$"
    }
}

GLOBAL_CONF_FILE_BASENAME      = "global_conf.yaml"
PERSONAL_INFO_AND_SECRETS_FILE = "personal_info_and_secrets.yaml"


def extract_global_conf_on_local_machine():

    current_dir                    = Path(__file__).parent
    repo_root_dir                  = Path(__file__).parent.parent.parent.parent
    global_conf_file               = current_dir.parent / GLOBAL_CONF_FILE_BASENAME 
    personal_info_and_secrets_yaml = repo_root_dir / PERSONAL_INFO_AND_SECRETS_FILE

    if not personal_info_and_secrets_yaml.exists() and not global_conf_file.exists():
        print("personal_info_and_secrets_yaml not exist")
        raise Exception(f"Both {personal_info_and_secrets_yaml.resolve()} and {global_conf_file.resolve()} does not exist.\n"
                        f"One of them must exist.\n"
                        f"If you are working from the local workstation, please define {personal_info_and_secrets_yaml.resolve()}")
    
    if personal_info_and_secrets_yaml.exists():
        personal_info_and_secrets = yaml_to_dict(personal_info_and_secrets_yaml)
        global_conf = {
            "profile" : personal_info_and_secrets["profile"],
            "region" : personal_info_and_secrets["region"],
            "namespace" : personal_info_and_secrets["namespace"]
        }

        with open(global_conf_file, 'w') as f:
            yaml.dump(global_conf, f, default_flow_style=False)
    else:
        global_conf = yaml_to_dict(global_conf_file)

    return global_conf


def load_global_conf():
    
    # Method 1: Try importlib.resources (works when packaged)
    try:
        with resources.open_text('ofirydevops', GLOBAL_CONF_FILE_BASENAME) as f:
            return yaml.safe_load(f)
    except (ImportError, FileNotFoundError, ModuleNotFoundError):
        pass
    
    # Method 2: Fallback to file path (works during local development)

    global_conf = extract_global_conf_on_local_machine()
    return global_conf



def load_and_validate_global_conf():
    global_conf = load_global_conf()
    validator   = Validator(GLOBAL_CONF_SCEHMA)
    if not validator.validate(global_conf):
        raise Exception(f"global_conf validation failed: {validator.errors}")
    return global_conf


def get_profile_and_region():
    global_conf = load_and_validate_global_conf()
    return global_conf["profile"], global_conf["region"]


def get_namespace():
    global_conf = load_and_validate_global_conf()
    return global_conf["namespace"]


def get_boto3_session():
    profile, region = get_profile_and_region()
    session = boto3.session.Session(
        region_name  = region,
        profile_name = profile
    )
    return session


def get_ssm_param(param_name):
    session  = get_boto3_session()
    ssm      = session.client('ssm')
    response = ssm.get_parameter(
                      Name=param_name, 
                      WithDecryption=True
                      )
    return response['Parameter']['Value']


def auth_ecr(region, profile, ecr_registry):
    ecr_auth_cmd = f'aws ecr get-login-password --region {region} --profile {profile} | ' \
                   f'docker login --username AWS --password-stdin {ecr_registry}'
    subprocess.run(ecr_auth_cmd, check=True,  shell=True)


def get_ecr_registry(session, region):

    sts_client = session.client("sts")
    response   = sts_client.get_caller_identity()
    account_id = response["Account"]
    return f"{account_id}.dkr.ecr.{region}.amazonaws.com"

def decrypt_git_repo(sm_secret_name, sm_secret_key_name):

    session                = get_boto3_session()
    sm                     = session.client('secretsmanager')
    response               = sm.get_secret_value(SecretId = sm_secret_name)
    secret_string          = response["SecretString"]
    gitcrypt_key_base64    = json.loads(secret_string)[sm_secret_key_name]
    gitcrypt_key           = base64.b64decode(gitcrypt_key_base64)
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


def run_shell_cmd_without_buffering(command, cwd=None):
    # Collect stderr for exception
    stderr_output = []

    # Ensure unbuffered output for Python subprocesses
    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"

    try:
        # Start the subprocess
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            shell=True,
            bufsize=1,
            universal_newlines=True,
            env=env,
            cwd=cwd
        )

        sel = selectors.DefaultSelector()
        sel.register(process.stdout, selectors.EVENT_READ)
        sel.register(process.stderr, selectors.EVENT_READ)

        while True:
            events = sel.select(timeout=0.1)
            for key, _ in events:
                line = key.fileobj.readline().strip()
                if not line:
                    continue

                if key.fileobj is process.stdout:
                    print(line)
                else:  # stderr
                    stderr_output.append(line)
                    print(line, file=sys.stderr)

            if process.poll() is not None:
                break

        # Drain any remaining output
        for stream, is_stderr in [(process.stdout, False), (process.stderr, True)]:
            while line := stream.readline().strip():
                if is_stderr:
                    stderr_output.append(line)
                    print(line, file=sys.stderr)
                else:
                    print(line)

        return_code = process.returncode
        if return_code != 0:
            stderr_message = "\n".join(stderr_output) if stderr_output else f"Command exited with code {return_code}"
            raise RuntimeError(stderr_message)

        return return_code

    finally:
        process.stdout.close()
        process.stderr.close()


def generate_random_string(length=10):
    lowercase_letters = string.ascii_lowercase
    random_string     = ''.join(random.choice(lowercase_letters) for _ in range(length))
    return random_string

