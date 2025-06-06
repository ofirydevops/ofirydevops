# import batch_runner.parent.main as batch_runner_parent

import asyncio
import subprocess
import json
import aws_batch_runner.main as runner

DOCKER_COMPOSE_FILE = "batch_runner/test/docker/docker-compose.yml"
# DOCKER_COMPOSE_FILE = "docker/docker-compose.yml"

async def main():

    test_dc_service = "main"

    subprocess.run(
        f"docker compose -f {DOCKER_COMPOSE_FILE} build {test_dc_service}", 
        check = True,
        shell = True
    )

    result = subprocess.run(
        f"docker compose -f {DOCKER_COMPOSE_FILE} config --format json",
        capture_output = True,
        text           = True,
        check          = True,
        shell          = True
    )
    docker_compose_config = json.loads(result.stdout)

    image_url = docker_compose_config["services"][test_dc_service]["image"]

    child_jobs_input = {
        "job_1" : "batch_runner/test/job_input_example.json",
        # "job_1" : "job_input_example.json",

        "job_2" : {
            "hello" : "world"
        }
    }

    response = await runner.run_batch(name                 = "test_run", 
                                           batch_env            = "main_arm64", 
                                           child_job_image      = image_url, 
                                           child_inputs         = child_jobs_input,
                                           child_job_entrypoint = r"python3.10 -m batch_runner.test.child --input-path ${CHILDJOB_INPUT_PATH}")


    print(json.dumps(response, indent=4))


if __name__ == "__main__":
    asyncio.run(main())


# export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
#   --domain test-py \
#   --domain-owner 961341530050 \
#   --region eu-central-1 \
#   --query authorizationToken --output text --profile OFIRYDEVOPS)


# upload:

# aws codeartifact login \
#    --tool twine \
#    --domain test-py \
#    --domain-owner 961341530050 \
#    --repository test-repo \
#    --region eu-central-1 \
#    --profile OFIRYDEVOPS

# pip3.10 install build
# python3.10 -m build
# python3.10 setup.py sdist bdist_wheel
# twine upload --repository codeartifact dist/*