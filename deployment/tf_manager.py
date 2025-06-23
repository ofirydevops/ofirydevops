import argparse
import os
import json
from pylib.ofirydevops.utils import main as utils

TF_PROJECTS_CONF_FILE = "deployment/tf_projects.yaml"
SECRETS_FILE          = "personal_info_and_secrets.yaml"


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

    tf_backend_config_file = f"backend.config-{utils.generate_random_string()}.json"
    if project == "root":
        if not os.path.exists(SECRETS_FILE):
            raise Exception(f"The root TF project must run from where the {SECRETS_FILE} file is available (usually local workstation).")
        
        tf_backend_config = utils.yaml_to_dict(SECRETS_FILE)["tf_backend_config"]

        with open(tf_backend_config_file, "w") as f:
            json.dump(tf_backend_config, f, indent=4)
    else:
        ssm_key = f"/{namespace}/tf_backend_config_json"

        tf_backend_config = json.loads(utils.get_ssm_param(ssm_key))
        with open(tf_backend_config_file, "w") as f:
            json.dump(tf_backend_config, f, indent=4)
    
    return tf_backend_config_file


def main():
    args = get_args()


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
    finally:
        os.remove(tf_backend_config_file)


if __name__ == "__main__":
    main()

