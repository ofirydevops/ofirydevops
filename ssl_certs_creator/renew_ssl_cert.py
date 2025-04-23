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


def get_aws_creds_from_ssm(region, profile):

    session = boto3.session.Session(
        region_name = region,
        profile_name = profile
    )
    ssm = session.client('ssm')
    aws_access_key_id_response = ssm.get_parameter(
        Name='/secrets/aws_access_key_id',
        WithDecryption=True
    )
    
    aws_secret_access_key_response = ssm.get_parameter(
        Name='/secrets/aws_secret_access_key',
        WithDecryption=True
    )
    aws_access_key_id = aws_access_key_id_response['Parameter']['Value']
    aws_secret_access_key = aws_secret_access_key_response['Parameter']['Value']
    return aws_access_key_id, aws_secret_access_key


def create_ssl_cert(domain):

    with open(GLOBAL_CONF_JSON_PATH, 'r') as f:
        global_conf = json.load(f)

    aws_access_key_id, aws_secret_access_key = get_aws_creds_from_ssm(global_conf["region"], global_conf["profile"])

    os.environ["AWS_REGION"]            = global_conf["region"]
    os.environ["DOMAIN"]                = domain
    os.environ["EMAIL"]                 = global_conf["email"]
    os.environ["AWS_ACCESS_KEY_ID"]     = aws_access_key_id
    os.environ["AWS_SECRET_ACCESS_KEY"] = aws_secret_access_key

    subprocess.run(["docker", "compose", "-f", "ssl_certs_creator/docker/docker-compose.yml", "run", "main"], check=True)

def main():

    args = get_args()

    create_ssl_cert(args["domain"])


if __name__ == "__main__":
    main()

