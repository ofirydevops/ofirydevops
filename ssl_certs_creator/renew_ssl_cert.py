import os
import subprocess
import json
import boto3
import argparse

GLOBAL_CONF_JSON_PATH = "global_conf.json"


def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--domain',
                             required = True,
                             dest    = 'domain')
    args = vars(args_parser.parse_args())
    return args


def create_ssl_cert(domain):
    with open(GLOBAL_CONF_JSON_PATH, 'r') as f:
        global_conf = json.load(f)

    session = boto3.session.Session(
        region_name = global_conf["region"],
        profile_name = global_conf["profile"]
    )
    credentials = session.get_credentials()

    os.environ["AWS_REGION"]            = global_conf["region"]
    os.environ["DOMAIN"]                = domain
    os.environ["EMAIL"]                 = global_conf["email"]
    os.environ["AWS_ACCESS_KEY_ID"]     = credentials.access_key
    os.environ["AWS_SECRET_ACCESS_KEY"] = credentials.secret_key
    os.environ["AWS_SESSION_TOKEN"]     = credentials.token

    subprocess.run(["docker", "compose", "-f", "ssl_certs_creator/docker/docker-compose.yml", "run", "main"], check=True)

def main():

    args = get_args()

    create_ssl_cert(args["domain"])


if __name__ == "__main__":
    main()

