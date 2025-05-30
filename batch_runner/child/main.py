import os
import subprocess
import boto3
import json
import batch_runner.utils as utils
import batch_runner.cnfg as cnfg


def consume_sqs_message(region, sqs_url):
    sqs = boto3.client('sqs', region_name = region)

    response = sqs.receive_message(
        QueueUrl            = sqs_url,
        MaxNumberOfMessages = 1
    )

    if 'Messages' not in response or not response['Messages']:
        return None

    message = response['Messages'][0]
    return message


def delete_sqs_message(region, sqs_url, receipt_handle):
    sqs = boto3.client('sqs', region_name = region)

    sqs.delete_message(
        QueueUrl      = sqs_url,
        ReceiptHandle = receipt_handle
    )


def download_input_from_s3(region, bucket, key, local_path):

    s3 = boto3.client('s3', region_name = region)

    s3.download_file(
        Bucket   = bucket,
        Key      = key,
        Filename = local_path
    )


def store_child_job_metadata_in_s3(region, bucket, s3_dir, child_job_name):

    child_job_index = os.environ["AWS_BATCH_JOB_ARRAY_INDEX"]

    data = {
        child_job_index: child_job_name
    }

    s3 = boto3.client('s3', region_name = region)

    s3.put_object(
        Bucket      = bucket,
        Key         = os.path.join(s3_dir, f'{child_job_index}.json'),
        Body        = json.dumps(data),
        ContentType = 'application/json'
    )


def main():

    print("Hello World")
    sqs_url              = os.environ["SQS_URL"]
    batch_run_id         = os.environ["BATCH_RUN_ID"]
    child_job_image      = os.environ["CHILDJOB_IMAGE"]
    child_job_entrypoint = os.environ["CHILDJOB_ENTERYPOINT"]
    batch_region         = os.environ["BATCH_REGION"]
    batch_bucket         = os.environ["BATCH_BUCKET"]
    batch_outputs_s3_dir = os.environ["BATCH_OUTPUTS_S3_DIR"]
    compose_service      = os.environ["BATCH_COMPOSE_SERVICE"]


    message = consume_sqs_message(batch_region, sqs_url)

    if not message:
        print("SQS is empty, finising job.")
        return
        
    message_dict = json.loads(message['Body'])

    child_job_input_s3_key = message_dict["s3_key"]
    child_job_name         = message_dict["child_job_name"]

    store_child_job_metadata_in_s3(batch_region, 
                                   batch_bucket, 
                                   batch_outputs_s3_dir, 
                                   child_job_name)

    local_input_dir = os.path.join(cnfg.CHILD_JOBS_INPUT_PATH, utils.generate_random_string())

    os.makedirs(local_input_dir)

    local_input_path = os.path.join(local_input_dir, os.path.basename(child_job_input_s3_key))

    download_input_from_s3(batch_region, batch_bucket, child_job_input_s3_key, local_input_path)

    env_vars = {
        "CHILDJOB_IMAGE":        child_job_image,
        "CHILDJOB_VOLUME_PATH":  local_input_dir,
        "CHILDJOB_NAME":         child_job_name,
        "CHILDJOB_BATCH_RUN_ID": batch_run_id,
        "CHILDJOB_INPUT_PATH":   local_input_path,
        "CHILDJOB_ENTERYPOINT":  child_job_entrypoint
    }
    print(json.dumps(env_vars, indent=4))
    
    ecr_registry = child_job_image.split('/')[0]

    ecr_auth_cmd = f'aws ecr get-login-password --region {batch_region} | ' \
                   f'docker login --username AWS --password-stdin {ecr_registry}'
    
    subprocess.run(ecr_auth_cmd, check=True, shell=True)

    subprocess.run(f"docker compose -f batch_runner/child/docker/docker-compose.yml run --quiet-pull {compose_service}", 
                   check = True,
                   shell = True,
                   env   = env_vars)

    receipt_handle = message['ReceiptHandle']

    delete_sqs_message(batch_region, sqs_url, receipt_handle)


if __name__ == "__main__":
    main()