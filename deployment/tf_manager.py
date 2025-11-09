import argparse
import os
import json
from cerberus import Validator
from pylib.ofirydevops.utils import main as utils

TF_PROJECTS_CONF_FILE        = "deployment/tf_projects.yaml"
TF_PROJECTS_CONF_FILE_SCHEMA = "deployment/schemas/tf_projects_file_schema.yaml"
INFO_SECRETS_FILE            = "personal_info_and_secrets.yaml"
INFO_SECRETS_FILE_SCHEMA     = "deployment/schemas/info_file_schema.yaml"

def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--tf-project',
                             required = True,
                             choices  = utils.yaml_to_dict(TF_PROJECTS_CONF_FILE).keys(),
                             dest     = 'tf_project')
    args_parser.add_argument('--tf-action',
                             required = True,
                             choices  = ["apply", "destroy", "plan", "validate"],
                             dest     = 'tf_action')
    args = vars(args_parser.parse_args())
    return args


def generate_tf_config_backend_file(namespace, project):

    tf_backend_config_file = f"tmp/backend.config-{utils.generate_random_string()}.json"
    os.makedirs(os.path.dirname(tf_backend_config_file), exist_ok=True)

    if project == "root":
        if not os.path.exists(INFO_SECRETS_FILE):
            raise Exception(f"The root TF project must run from where the {INFO_SECRETS_FILE} file is available (usually local workstation).")
        
        validate_file_and_normalize(INFO_SECRETS_FILE, INFO_SECRETS_FILE_SCHEMA)
        
        tf_backend_config = utils.yaml_to_dict(INFO_SECRETS_FILE)["tf_backend_config"]

        with open(tf_backend_config_file, "w") as f:
            json.dump(tf_backend_config, f, indent=4)
    else:
        ssm_key = f"/{namespace}/tf_backend_config_json"

        tf_backend_config = json.loads(utils.get_ssm_param(ssm_key))
        with open(tf_backend_config_file, "w") as f:
            json.dump(tf_backend_config, f, indent=4)
    
    return tf_backend_config_file


def validate_file_and_normalize(data_file, schema_file):
    data      = utils.yaml_to_dict(data_file)
    schema    = utils.yaml_to_dict(schema_file)
    validator = Validator(schema)
    if validator.validate(data):
        print(f"{data_file} validation successful!")
    else:
        raise Exception(f"{data_file} validation failed: {validator.errors}")
    return validator.normalized(data)


def main():
    args = get_args()

    validate_file_and_normalize(TF_PROJECTS_CONF_FILE, TF_PROJECTS_CONF_FILE_SCHEMA)

    tf_projects_conf = utils.yaml_to_dict(TF_PROJECTS_CONF_FILE)
    project          = args["tf_project"]
    action           = args["tf_action"]
    project_path     = tf_projects_conf[project]["path"]
    namespace        = utils.get_namespace()

    tf_backend_config_file = generate_tf_config_backend_file(namespace, project)

    if action == "apply" or action == "destroy":
        flags = "-auto-approve"
    else:
        flags = ""

    try:
        utils.run_shell_cmd_without_buffering(f"terraform init -backend-config={os.path.abspath(tf_backend_config_file)}", cwd=project_path)
        utils.run_shell_cmd_without_buffering(f"terraform workspace select -or-create {namespace}",                        cwd=project_path)
        utils.run_shell_cmd_without_buffering(f"terraform {action} {flags}",                                               cwd=project_path)
        
        if action == "apply":
            utils.run_shell_cmd_without_buffering(f"terraform output", cwd=project_path)

    finally:
        os.remove(tf_backend_config_file)


if __name__ == "__main__":
    main()

