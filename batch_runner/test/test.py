import batch_runner.parent.main as batch_runner_parent
import asyncio
import subprocess
import json
import data_science.scripts.build_py_env as build_py_env

async def main():

    # test_dc_service = "main"

    # subprocess.run(
    #     f"docker compose -f batch_runner/test/docker/docker-compose.yml build {test_dc_service}", 
    #     check = True,
    #     shell = True
    # )

    # result = subprocess.run(
    #     "docker compose -f batch_runner/test/docker/docker-compose.yml config --format json",
    #     capture_output = True,
    #     text           = True,
    #     check          = True,
    #     shell          = True
    # )
    # docker_compose_config = json.loads(result.stdout)

    # image_url = docker_compose_config["services"][test_dc_service]["image"]

    child_jobs_input = {
        "job_1" : "global_conf.json",
        "job_2" : {
            "hello" : "world"
        }
    }

    # response = await batch_runner_parent.run_batch(name                 = "test_run", 
    #                                                batch_env            = "main_amd64", 
    #                                                child_job_image      = image_url, 
    #                                                child_inputs         = child_jobs_input,
    #                                                child_job_entrypoint = r"python3.10 -m batch_runner.test.child --input-path ${CHILDJOB_INPUT_PATH}")
    

    image_url = build_py_env.build_py_env({"py_env_conf_file": "data_science/conda_envs_v2/py310_gpu.yaml"})

    response = await batch_runner_parent.run_batch(name                 = "test_run",
                                                   batch_env            = "gpu_amd64", 
                                                   child_job_image      = image_url, 
                                                   child_inputs         = child_jobs_input,
                                                   child_job_entrypoint = r"python data_science/torch_gpu_test.py")

    
    
    print(json.dumps(response, indent=4))

if __name__ == "__main__":
    asyncio.run(main())
