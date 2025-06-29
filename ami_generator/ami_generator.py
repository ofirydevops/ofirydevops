import argparse
import json
from os.path import dirname
import os
import subprocess
import uuid
import datetime
from pylib.ofirydevops.utils import main as utils

PACKER_CONF_FILE = "ami_generator/main_conf.yaml"


def get_default_vpc_id():
    session = utils.get_boto3_session()
    ec2 = session.client('ec2')

    response = ec2.describe_vpcs(
        Filters=[
            {
                'Name': 'is-default',
                'Values': ['true']
            }
        ]
    )
    vpc_id = response['Vpcs'][0]['VpcId']

    return vpc_id


def get_public_subnet_id(vpc_id):
    session = utils.get_boto3_session()
    ec2 = session.client('ec2')
    
    try:
        response = ec2.describe_subnets(
            Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}]
        )
        subnets = response['Subnets']
        if not subnets:
            print(f"No subnets found for VPC {vpc_id}")
            return None

        for subnet in subnets:
            subnet_id = subnet['SubnetId']
            
            route_tables_response = ec2.describe_route_tables(
                Filters=[{'Name': 'association.subnet-id', 'Values': [subnet_id]}]
            )
            
            # If no explicit route table association, check the VPC's main route table
            if not route_tables_response['RouteTables']:
                route_tables_response = ec2.describe_route_tables(
                    Filters=[
                        {'Name': 'vpc-id', 'Values': [vpc_id]},
                        {'Name': 'association.main', 'Values': ['true']}
                    ]
                )
            
            # Check each route table for an Internet Gateway route
            for route_table in route_tables_response['RouteTables']:
                for route in route_table['Routes']:
                    if route.get('DestinationCidrBlock') == '0.0.0.0/0' and 'GatewayId' in route and route['GatewayId'].startswith('igw-'):
                        print(f"Public subnet found: {subnet_id}")
                        return subnet_id
        
        print(f"No public subnets found in VPC {vpc_id}")
        return None
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return None


def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--conf',
                             required = True,
                             choices  = utils.yaml_to_dict(PACKER_CONF_FILE).keys(),
                             dest     = 'conf')
    args = vars(args_parser.parse_args())
    return args

def get_formatted_timestamp():
    timestamp           = datetime.datetime.now().timestamp()
    formatted_timestamp = datetime.datetime.fromtimestamp(timestamp).strftime("%d_%m_%Y__%H_%M")
    return formatted_timestamp


def create_packer_input_file(input_dict):
    tmp_dir_path = "tmp"
    os.makedirs(tmp_dir_path, exist_ok=True)
    packer_input_file_path = os.path.join(tmp_dir_path, f'pkr_input_{uuid.uuid4()}.json')
    with open(packer_input_file_path, "w") as packer_input_file:
        packer_input_file.write(json.dumps(input_dict))
    return packer_input_file_path
    


def run_packer(packer_hcl_path, packer_input_file_path):
    
    subprocess.run(["packer", "init", dirname(packer_hcl_path)], check=True)
    subprocess.run(["packer", "build", f"-var-file={packer_input_file_path}", packer_hcl_path], check=True)


def store_ami_ids_in_ssm(input_dict):

    session   = utils.get_boto3_session()
    ec2       = session.client('ec2')
    ssm       = session.client('ssm')

    for ami_conf in input_dict["images"].values():

        response = ec2.describe_images(
            Filters = [
                {
                    'Name' : 'name',
                    'Values' : [ami_conf["ami_name"]]
                }
            ]
        )

        ami_id = response["Images"][0]["ImageId"]

        ssm_key = ami_conf["ami_id_ssm_key"]

        ssm.put_parameter(
            Name      = ssm_key,
            Value     = ami_id,
            Type      = 'String',
            DataType  = 'aws:ec2:image',
            Overwrite = True
        )

        print(f'Successfully stored ami id {ami_id} in {ssm_key}')


def get_ssh_private_key_file():
    tmp_dir_path = "tmp"
    os.makedirs(tmp_dir_path, exist_ok=True)

    namespace            = utils.get_namespace()
    ssh_private_key_file = os.path.join(tmp_dir_path, f"{utils.generate_random_string()}_private_key.pem")
    ssh_private_key      = utils.get_ssm_param(f"/{namespace}/secrets/main_keypair_privete_key")
    with open(ssh_private_key_file, "w") as file:
        file.write(ssh_private_key)
    return ssh_private_key_file


def get_ssh_keypair_name():
    namespace        = utils.get_namespace()
    ssh_keypair_name = utils.get_ssm_param(f"/{namespace}/main_keypair_name")
    return ssh_keypair_name


def main():
    args                 = get_args()
    input_dict           = utils.yaml_to_dict(PACKER_CONF_FILE)[args["conf"]]
    vpc_id               = get_default_vpc_id()
    profile, region      = utils.get_profile_and_region()
    namespace            = utils.get_namespace()
    ssh_private_key_file = get_ssh_private_key_file()
    subnet_id            = get_public_subnet_id(vpc_id)
    ssh_keypair_name     = get_ssh_keypair_name()
 
    input_dict["ssh_private_key_file"] = ssh_private_key_file
    input_dict["ssh_keypair_name"]     = ssh_keypair_name
    input_dict["subnet_id"]            = subnet_id
    input_dict["vpc_id"]               = vpc_id
    input_dict["profile"]              = profile
    input_dict["region"]               = region
    input_dict["images"]               = {}

    timestamp = get_formatted_timestamp()

    for volume_size in input_dict["volume_sizes_in_gb"]:
        image                       = f'{args["conf"]}_{volume_size}GB'
        input_dict["images"][image] = {
            "ami_name"       : f'PACKER_{namespace}_{image}__{timestamp}',
            "volume_size"    : volume_size,
            "ami_id_ssm_key" : f"/{namespace}/ami_id/{image}"
        }

    print(json.dumps(input_dict, indent=4))

    try:
        packer_input_file_path = create_packer_input_file(input_dict)
        run_packer(input_dict["packer_hcl_path"], packer_input_file_path)
        store_ami_ids_in_ssm(input_dict)
    finally:
        os.remove(ssh_private_key_file)
        os.remove(packer_input_file_path)


if __name__ == "__main__":
    main()

