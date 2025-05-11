import json
from os.path import dirname
import os
import subprocess
import uuid
import boto3
import yaml
import base64
import selectors
import sys

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


def run_command(command):
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
            env=env
        )

        # Use selectors to monitor stdout and stderr in real-time
        sel = selectors.DefaultSelector()
        sel.register(process.stdout, selectors.EVENT_READ)
        sel.register(process.stderr, selectors.EVENT_READ)

        while True:
            # Check for available data on stdout or stderr
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

            # Check if the process has finished
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

        # Check the return code and raise exception if command failed
        return_code = process.returncode
        if return_code != 0:
            stderr_message = "\n".join(stderr_output) if stderr_output else f"Command exited with code {return_code}"
            raise RuntimeError(stderr_message)

        return return_code

    finally:
        # Clean up
        process.stdout.close()
        process.stderr.close()