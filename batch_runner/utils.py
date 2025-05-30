import json
import boto3
import random
import string

GLOBAL_CONF_JSON = "global_conf.json"


def get_boto3_session():
    with open(GLOBAL_CONF_JSON, "r") as global_conf_file:
        global_conf = json.load(global_conf_file)

    session = boto3.session.Session(
        region_name = global_conf["region"],
        profile_name = global_conf["profile"]
    )
    return session


def get_ssm_param(param_name):
    session  = get_boto3_session()
    ssm      = session.client('ssm')
    response = ssm.get_parameter(Name=param_name)
    return response['Parameter']['Value']



def generate_random_string(length=10):
    lowercase_letters = string.ascii_lowercase
    random_string = ''.join(random.choice(lowercase_letters) for _ in range(length))
    return random_string