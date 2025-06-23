import json
import os
from cerberus import Validator
from botocore.exceptions import ClientError
from . import cnfg
from ..utils import main as utils


def validate_batch_conf_ssm_param(field, value, error):
    try:
        ssm_value = json.loads(utils.get_ssm_param(f"{cnfg.BATCH_ENV_SSM_PARAM_PREFIX}{value}"))

        ssm_validator = Validator(BATCH_CONF_SCHEMA)
        if not ssm_validator.validate(ssm_value):
            error(field, f"SSM parameter {value} validation failed: {ssm_validator.errors}")

    except json.JSONDecodeError:
        error(field, "SSM parameter value is not valid JSON")
    except ClientError as e:
        if e.response['Error']['Code'] == 'ParameterNotFound':
            error(field, f"Parameter '{value}' does not exist.")
        else:
            raise


def validate_child_input_value(field, value, error):
    if isinstance(value, str):
        if not os.path.isfile(value):
            error(field, f"'{value}' is not a path to an existing file")
    elif not isinstance(value, dict):
        error(field, "Value must be either a path to an existing file or a dictionary")


BATCH_CONF_SCHEMA = {
    "batch_job_queue_arn": {
        "type": "string",
        "required": True,
        "regex": r"^arn:aws:batch:[a-z0-9-]+:[0-9]{12}:job-queue/[a-zA-Z0-9_-]+$"
    },
    "bucket": {
        "type": "string",
        "required": True,
        "regex": r"^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$"
    },
    "profile": {
        "type": "string",
        "required": True,
        "regex": r"^[a-zA-Z0-9_-]+$"
    },
    "region": {
        "type": "string",
        "required": True,
        "regex": r"^[a-z]{2}-[a-z]+-[0-9]+$"
    },
    "ecr_repo_url": {
        "type": "string",
        "required": True,
        "regex": r"^[0-9]{12}\.dkr\.ecr\.[a-z]{2}-[a-z]+-[0-9]+\.amazonaws\.com/[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)*$"
    },
    "image_tag_prefix": {
        "type": "string",
        "required": True,
        "regex": r"^[a-zA-Z0-9][a-zA-Z0-9._-]{0,127}$"
    },
    "batch_artifacts_s3_dir": {
        "type": "string",
        "required": True,
        "regex": r'^[a-zA-Z0-9._\-/]+$'
    },
    "vcpus_per_childjob": {
        "type": "integer",
        "required": True
    },
    "memory_mb_per_childjob": {
        "type": "integer",
        "required": True
    },
    "child_wrapper_image": {
        "type": "string",
        "required": True,
        "regex": r"^([a-z0-9]+([._-][a-z0-9]+)*\/)*[a-z0-9]+([._-][a-z0-9]+)*(:[a-zA-Z0-9._-]+)?$"
    },
    "compose_service": {
        "type": "string",
        "required": True,
        "regex": r"^[a-zA-Z0-9][a-zA-Z0-9_.-]*$"
    }
}


INPUTS_SCHEMA = {
    "batch_env": {
        "type": "string",
        "required": True,
        "regex": r"^[a-zA-Z0-9_/.-]+$",
        "check_with": validate_batch_conf_ssm_param
    },
    "child_job_image": {
        "type": "string",
        "required": True,
        "regex": r"^([a-z0-9]+([._-][a-z0-9]+)*\/)*[a-z0-9]+([._-][a-z0-9]+)*(:[a-zA-Z0-9._-]+)?$"
    },
    "child_job_entrypoint": {
        "type": "string",
        "required": True
    },
    "name": {
        "type": "string",
        "required": True,
        "regex": r"^[a-zA-Z]+[a-zA-Z0-9._-]{0,50}$"
    },
    "child_inputs": {
        "type": "dict",
        "required": True,
        "keysrules": {
            "type": "string",
            "regex": r"^[a-zA-Z0-9_-]+$"
        },
        "valuesrules": {
            "type": ["string", "dict"],
            "check_with": validate_child_input_value
        }
    }
}

