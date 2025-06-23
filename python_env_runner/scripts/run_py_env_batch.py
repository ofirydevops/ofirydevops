from pylib.ofirydevops.batch_runner import main as batch_runner
import python_env_runner.scripts.build_py_env as build_py_env
import asyncio
import argparse
import json
import yaml


def get_args():
    args_parser = argparse.ArgumentParser()
    args_parser.add_argument('--py-env-conf-file',
                             required = True,
                             type     = str,
                             dest     = 'py_env_conf_file')
    args_parser.add_argument('--docker-image-tag',
                             required = True,
                             type     = str,
                             dest     = 'docker_image_tag')
    args_parser.add_argument('--batch-env',
                             required = False,
                             type     = str,
                             default  = 'main_arm64',
                             dest     = 'batch_env')
    args_parser.add_argument('--child-jobs-input-file',
                             required = True,
                             type     = str,
                             dest     = 'child_jobs_input_file')
    args_parser.add_argument('--child-job-entrypoint',
                             required = True,
                             type     = str,
                             dest     = 'child_job_entrypoint')
    args = vars(args_parser.parse_args())
    return args


async def main(args):

    batch_run_name = args["docker_image_tag"]

    with open(args["child_jobs_input_file"], 'r') as child_jobs_input_file:
        child_jobs_input = yaml.safe_load(child_jobs_input_file)

    image_url = build_py_env.build_py_env(
        {
            "py_env_conf_file": args["py_env_conf_file"],
            "docker_image_tag": args["docker_image_tag"]
        }
    )

    response = await batch_runner.run_batch(name                 = batch_run_name,
                                            batch_env            = args["batch_env"], 
                                            child_job_image      = image_url, 
                                            child_inputs         = child_jobs_input,
                                            child_job_entrypoint = args["child_job_entrypoint"])

    print(json.dumps(response, indent=4))


if __name__ == "__main__":

    args = get_args()
    asyncio.run(main(args))
