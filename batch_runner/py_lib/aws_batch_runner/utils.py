import json
import boto3
import random
import string
from . import cnfg


def get_boto3_session():
    session = boto3.session.Session(
        region_name  = cnfg.MAIN_REGION,
        profile_name = cnfg.MAIN_PROFILE
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