
import asyncio
import subprocess
import json
import platform
from pathlib import Path
from ofirydevops.batch_runner import main as batch_runner


SCRIPT_DIR          = Path(__file__).parent
DOCKER_COMPOSE_FILE = SCRIPT_DIR / "docker" / "docker-compose.yml"



BATCH_ENV_ARCH_MAPPING = {
    "arm64"   : "main_arm64",
    "aarch64" : "main_arm64",
    "x86_64"  : "main_amd64"
}

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
        "job_1" : str(SCRIPT_DIR / "job_input_example.json"),

        "job_2" : {
            "hello" : "world"
        }
    }

    response = await batch_runner.run_batch(name                 = "test_run", 
                                            batch_env            = BATCH_ENV_ARCH_MAPPING[platform.machine()], 
                                            child_job_image      = image_url, 
                                            child_inputs         = child_jobs_input,
                                            child_job_entrypoint = r"python3.10 -m batch_runner.test.child --input-path ${CHILDJOB_INPUT_PATH}")


    print(json.dumps(response, indent=4))


if __name__ == "__main__":
    asyncio.run(main())
