from ..utils import main as utils

namespace = utils.get_namespace()

CHILD_JOBS_INPUT_PATH      = "/tmp/input"
CHILD_JOBS_INPUT_VOL_NAME  = "input"
DOCKER_SOCK_PATH           = "/var/run/docker.sock"
DOCKER_SOCK_VOL_NAME       = "docker_sock"
BATCH_ENV_SSM_PARAM_PREFIX = f"/{namespace}/batch_runner_conf/"
