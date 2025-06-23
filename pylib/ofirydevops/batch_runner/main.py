import json
import os
from cerberus import Validator
from datetime import datetime
import boto3
import asyncio
import aioboto3
import polling2
import subprocess
from ..utils import main as utils
from . import cnfg
from . import validation


# >>> jobs = batch.list_jobs(arrayJobId="e570d7be-dde4-4c3f-93b6-4bf09a0f2d37",jobStatus="SUCCEEDED")
# >>> print(json.dumps(jobs, indent=4))
# {
#     "ResponseMetadata": {
#         "RequestId": "8d259f1b-8b75-44da-868f-a46d910f6970",
#         "HTTPStatusCode": 200,
#         "HTTPHeaders": {
#             "date": "Tue, 27 May 2025 01:02:12 GMT",
#             "content-type": "application/json",
#             "content-length": "826",
#             "connection": "keep-alive",
#             "x-amzn-requestid": "8d259f1b-8b75-44da-868f-a46d910f6970",
#             "access-control-allow-origin": "*",
#             "x-amz-apigw-id": "LM9LQEBDFiAEWoQ=",
#             "access-control-expose-headers": "X-amzn-errortype,X-amzn-requestid,X-amzn-errormessage,X-amzn-trace-id,X-amz-apigw-id,date",
#             "x-amzn-trace-id": "Root=1-68350f14-62dbe60960aa2a4040789d56"
#         },
#         "RetryAttempts": 0
#     },
#     "jobSummaryList": [
#         {
#             "jobArn": "arn:aws:batch:eu-central-1:961341530050:job/e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:0",
#             "jobId": "e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:0",
#             "jobName": "test_run_pdtqnnunzs_2025_05_27__03_32",
#             "createdAt": 1748306091676,
#             "status": "SUCCEEDED",
#             "statusReason": "Essential container in task exited",
#             "startedAt": 1748306353164,
#             "stoppedAt": 1748306382485,
#             "container": {
#                 "exitCode": 0
#             },
#             "arrayProperties": {
#                 "index": 0
#             }
#         },
#         {
#             "jobArn": "arn:aws:batch:eu-central-1:961341530050:job/e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:1",
#             "jobId": "e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:1",
#             "jobName": "test_run_pdtqnnunzs_2025_05_27__03_32",
#             "createdAt": 1748306091676,
#             "status": "SUCCEEDED",
#             "statusReason": "Essential container in task exited",
#             "startedAt": 1748306353170,
#             "stoppedAt": 1748306382483,
#             "container": {
#                 "exitCode": 0
#             },
#             "arrayProperties": {
#                 "index": 1
#             }
#         }
#     ]
# }


# >>> status = batch.describe_jobs(jobs=["e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:0","e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:1"])
# >>> 
# >>> 
# >>> 
# >>> print(json.dumps(status, indent=4))
# {
#     "ResponseMetadata": {
#         "RequestId": "c7a70793-8d48-4bc6-b5b7-3e970d73524f",
#         "HTTPStatusCode": 200,
#         "HTTPHeaders": {
#             "date": "Tue, 27 May 2025 01:17:38 GMT",
#             "content-type": "application/json",
#             "content-length": "8079",
#             "connection": "keep-alive",
#             "x-amzn-requestid": "c7a70793-8d48-4bc6-b5b7-3e970d73524f",
#             "access-control-allow-origin": "*",
#             "x-amz-apigw-id": "LM_b8GoSFiAEPkw=",
#             "access-control-expose-headers": "X-amzn-errortype,X-amzn-requestid,X-amzn-errormessage,X-amzn-trace-id,X-amz-apigw-id,date",
#             "x-amzn-trace-id": "Root=1-683512b2-6903748e0bb5ca8a531597ae"
#         },
#         "RetryAttempts": 0
#     },
#     "jobs": [
#         {
#             "jobArn": "arn:aws:batch:eu-central-1:961341530050:job/e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:1",
#             "jobName": "test_run_pdtqnnunzs_2025_05_27__03_32",
#             "jobId": "e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:1",
#             "jobQueue": "arn:aws:batch:eu-central-1:961341530050:job-queue/main_arm64_batch_runner",
#             "status": "SUCCEEDED",
#             "attempts": [
#                 {
#                     "container": {
#                         "containerInstanceArn": "arn:aws:ecs:eu-central-1:961341530050:container-instance/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/3d44fec9a81f4f4fa755eac715a6d7ea",
#                         "taskArn": "arn:aws:ecs:eu-central-1:961341530050:task/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/4f1bf298b20642199195b4efee9d329e",
#                         "exitCode": 0,
#                         "logStreamName": "test_run_pdtqnnunzs_2025_05_27__03_32/default/4f1bf298b20642199195b4efee9d329e",
#                         "networkInterfaces": []
#                     },
#                     "startedAt": 1748306353170,
#                     "stoppedAt": 1748306382483,
#                     "statusReason": "Essential container in task exited"
#                 }
#             ],
#             "statusReason": "Essential container in task exited",
#             "createdAt": 1748306091676,
#             "startedAt": 1748306353170,
#             "stoppedAt": 1748306382483,
#             "dependsOn": [],
#             "jobDefinition": "arn:aws:batch:eu-central-1:961341530050:job-definition/test_run_pdtqnnunzs_2025_05_27__03_32:1",
#             "parameters": {},
#             "container": {
#                 "image": "961341530050.dkr.ecr.eu-central-1.amazonaws.com/batch_runner_wrapper:batch_child_wrapper_3cbdeb0c5d4e9a2",
#                 "command": [
#                     "pipenv",
#                     "run",
#                     "python3.10",
#                     "-m",
#                     "batch_runner.child.main"
#                 ],
#                 "volumes": [
#                     {
#                         "host": {
#                             "sourcePath": "/tmp/input"
#                         },
#                         "name": "input"
#                     },
#                     {
#                         "host": {
#                             "sourcePath": "/var/run/docker.sock"
#                         },
#                         "name": "docker_sock"
#                     }
#                 ],
#                 "environment": [
#                     {
#                         "name": "BATCH_RUN_ID",
#                         "value": "test_run_pdtqnnunzs_2025_05_27__03_32"
#                     },
#                     {
#                         "name": "CHILDJOB_ENTERYPOINT",
#                         "value": "python3.10 -m batch_runner.test.child --input-path ${CHILDJOB_INPUT_PATH}"
#                     },
#                     {
#                         "name": "BATCH_REGION",
#                         "value": "eu-central-1"
#                     },
#                     {
#                         "name": "CHILDJOB_IMAGE",
#                         "value": "961341530050.dkr.ecr.eu-central-1.amazonaws.com/main_arm64_batch_runner:batch_test_run_pdtqnnunzs_2025_05_27__03_32"
#                     },
#                     {
#                         "name": "BATCH_OUTPUTS_S3_DIR",
#                         "value": "batch_artifacts/2025_05_27/test_run_pdtqnnunzs_2025_05_27__03_32/outputs"
#                     },
#                     {
#                         "name": "BATCH_BUCKET",
#                         "value": "ofirydevops-batch-runner"
#                     },
#                     {
#                         "name": "SQS_URL",
#                         "value": "https://sqs.eu-central-1.amazonaws.com/961341530050/test_run_pdtqnnunzs_2025_05_27__03_32"
#                     }
#                 ],
#                 "mountPoints": [
#                     {
#                         "containerPath": "/tmp/input",
#                         "readOnly": false,
#                         "sourceVolume": "input"
#                     },
#                     {
#                         "containerPath": "/var/run/docker.sock",
#                         "readOnly": false,
#                         "sourceVolume": "docker_sock"
#                     }
#                 ],
#                 "ulimits": [],
#                 "exitCode": 0,
#                 "containerInstanceArn": "arn:aws:ecs:eu-central-1:961341530050:container-instance/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/3d44fec9a81f4f4fa755eac715a6d7ea",
#                 "taskArn": "arn:aws:ecs:eu-central-1:961341530050:task/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/4f1bf298b20642199195b4efee9d329e",
#                 "logStreamName": "test_run_pdtqnnunzs_2025_05_27__03_32/default/4f1bf298b20642199195b4efee9d329e",
#                 "networkInterfaces": [],
#                 "resourceRequirements": [
#                     {
#                         "value": "1",
#                         "type": "VCPU"
#                     },
#                     {
#                         "value": "3000",
#                         "type": "MEMORY"
#                     }
#                 ],
#                 "secrets": []
#             },
#             "arrayProperties": {
#                 "statusSummary": {},
#                 "index": 1
#             },
#             "timeout": {
#                 "attemptDurationSeconds": 3600
#             },
#             "tags": {},
#             "propagateTags": true,
#             "platformCapabilities": [
#                 "EC2"
#             ],
#             "eksAttempts": []
#         },
#         {
#             "jobArn": "arn:aws:batch:eu-central-1:961341530050:job/e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:0",
#             "jobName": "test_run_pdtqnnunzs_2025_05_27__03_32",
#             "jobId": "e570d7be-dde4-4c3f-93b6-4bf09a0f2d37:0",
#             "jobQueue": "arn:aws:batch:eu-central-1:961341530050:job-queue/main_arm64_batch_runner",
#             "status": "SUCCEEDED",
#             "attempts": [
#                 {
#                     "container": {
#                         "containerInstanceArn": "arn:aws:ecs:eu-central-1:961341530050:container-instance/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/3d44fec9a81f4f4fa755eac715a6d7ea",
#                         "taskArn": "arn:aws:ecs:eu-central-1:961341530050:task/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/de853efd7955472ba9175975b5972d61",
#                         "exitCode": 0,
#                         "logStreamName": "test_run_pdtqnnunzs_2025_05_27__03_32/default/de853efd7955472ba9175975b5972d61",
#                         "networkInterfaces": []
#                     },
#                     "startedAt": 1748306353164,
#                     "stoppedAt": 1748306382485,
#                     "statusReason": "Essential container in task exited"
#                 }
#             ],
#             "statusReason": "Essential container in task exited",
#             "createdAt": 1748306091676,
#             "startedAt": 1748306353164,
#             "stoppedAt": 1748306382485,
#             "dependsOn": [],
#             "jobDefinition": "arn:aws:batch:eu-central-1:961341530050:job-definition/test_run_pdtqnnunzs_2025_05_27__03_32:1",
#             "parameters": {},
#             "container": {
#                 "image": "961341530050.dkr.ecr.eu-central-1.amazonaws.com/batch_runner_wrapper:batch_child_wrapper_3cbdeb0c5d4e9a2",
#                 "command": [
#                     "pipenv",
#                     "run",
#                     "python3.10",
#                     "-m",
#                     "batch_runner.child.main"
#                 ],
#                 "volumes": [
#                     {
#                         "host": {
#                             "sourcePath": "/tmp/input"
#                         },
#                         "name": "input"
#                     },
#                     {
#                         "host": {
#                             "sourcePath": "/var/run/docker.sock"
#                         },
#                         "name": "docker_sock"
#                     }
#                 ],
#                 "environment": [
#                     {
#                         "name": "BATCH_RUN_ID",
#                         "value": "test_run_pdtqnnunzs_2025_05_27__03_32"
#                     },
#                     {
#                         "name": "CHILDJOB_ENTERYPOINT",
#                         "value": "python3.10 -m batch_runner.test.child --input-path ${CHILDJOB_INPUT_PATH}"
#                     },
#                     {
#                         "name": "BATCH_REGION",
#                         "value": "eu-central-1"
#                     },
#                     {
#                         "name": "CHILDJOB_IMAGE",
#                         "value": "961341530050.dkr.ecr.eu-central-1.amazonaws.com/main_arm64_batch_runner:batch_test_run_pdtqnnunzs_2025_05_27__03_32"
#                     },
#                     {
#                         "name": "BATCH_OUTPUTS_S3_DIR",
#                         "value": "batch_artifacts/2025_05_27/test_run_pdtqnnunzs_2025_05_27__03_32/outputs"
#                     },
#                     {
#                         "name": "BATCH_BUCKET",
#                         "value": "ofirydevops-batch-runner"
#                     },
#                     {
#                         "name": "SQS_URL",
#                         "value": "https://sqs.eu-central-1.amazonaws.com/961341530050/test_run_pdtqnnunzs_2025_05_27__03_32"
#                     }
#                 ],
#                 "mountPoints": [
#                     {
#                         "containerPath": "/tmp/input",
#                         "readOnly": false,
#                         "sourceVolume": "input"
#                     },
#                     {
#                         "containerPath": "/var/run/docker.sock",
#                         "readOnly": false,
#                         "sourceVolume": "docker_sock"
#                     }
#                 ],
#                 "ulimits": [],
#                 "exitCode": 0,
#                 "containerInstanceArn": "arn:aws:ecs:eu-central-1:961341530050:container-instance/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/3d44fec9a81f4f4fa755eac715a6d7ea",
#                 "taskArn": "arn:aws:ecs:eu-central-1:961341530050:task/AWSBatch-main_arm64_batch_runner-37235f86-9457-3c6c-ab7d-5cbbd096aded/de853efd7955472ba9175975b5972d61",
#                 "logStreamName": "test_run_pdtqnnunzs_2025_05_27__03_32/default/de853efd7955472ba9175975b5972d61",
#                 "networkInterfaces": [],
#                 "resourceRequirements": [
#                     {
#                         "value": "1",
#                         "type": "VCPU"
#                     },
#                     {
#                         "value": "3000",
#                         "type": "MEMORY"
#                     }
#                 ],
#                 "secrets": []
#             },
#             "arrayProperties": {
#                 "statusSummary": {},
#                 "index": 0
#             },
#             "timeout": {
#                 "attemptDurationSeconds": 3600
#             },
#             "tags": {},
#             "propagateTags": true,
#             "platformCapabilities": [
#                 "EC2"
#             ],
#             "eksAttempts": []
#         }
#     ]
# }

def tag_and_push_image_to_ecr(profile, region, ecr_registry, source_image, target_image):
    ecr_auth_cmd = f'aws ecr get-login-password --region {region} --profile {profile} | ' \
                   f'docker login --username AWS --password-stdin {ecr_registry}'
    
    subprocess.run(ecr_auth_cmd,                                check=True,  shell=True)
    subprocess.run(f"docker pull {source_image}",               check=False, shell=True)
    subprocess.run(f"docker tag {source_image} {target_image}", check=True,  shell=True)
    subprocess.run(f"docker push {target_image}",               check=True,  shell=True)


def get_job_artifacts_s3_dir(batch_conf, batch_run_id, current_datetime):
    datetime_str = current_datetime.strftime("%Y_%m_%d")
    prefix_path  = f'{batch_conf["batch_artifacts_s3_dir"]}/{datetime_str}/{batch_run_id}'
    return prefix_path


async def upload_and_queue_child_input(s3_client, 
                                       sqs_client, 
                                       bucket, 
                                       sqs_url, 
                                       s3_key_prefix,
                                       child_job_name,
                                       child_job_input):
    s3_key = None

    if isinstance(child_job_input, dict):
        s3_key = f'{s3_key_prefix}/{child_job_name}.json'

        await s3_client.put_object(
            Bucket = bucket,
            Key    = s3_key,
            Body   = json.dumps(child_job_input),
            ContentType='application/json'
        )
    elif isinstance(child_job_input, str) and os.path.isfile(child_job_input):
        s3_key = f'{s3_key_prefix}/{child_job_name}_{os.path.basename(child_job_input)}'

        await s3_client.upload_file(
            Filename = child_job_input,
            Bucket   = bucket,
            Key      = s3_key
        )
    else:
        raise Exception(f"Child input {child_job_name} value is not dict nor a file path")
    
    message_body = {
        "s3_key" : s3_key,
        "child_job_name" : child_job_name
    }
    await sqs_client.send_message(
        QueueUrl = sqs_url,
        MessageBody = json.dumps(message_body)
    )
    print(f"Sent S3 key {s3_key} to SQS queue {sqs_url}")


async def upload_and_queue_child_inputs(batch_conf,
                                        child_inputs, 
                                        sqs_url, 
                                        s3_key_prefix):
    session = aioboto3.Session(        
        region_name = batch_conf["region"],
        profile_name = batch_conf["profile"]
    )
    async with session.client("s3") as s3_client, session.client("sqs") as sqs_client:
        tasks = []
        for child_job_name, child_job_input in child_inputs.items():
            task = asyncio.create_task(
                upload_and_queue_child_input(s3_client, 
                                             sqs_client, 
                                             batch_conf["bucket"], 
                                             sqs_url, 
                                             s3_key_prefix,
                                             child_job_name,
                                             child_job_input)
            )
            tasks.append(task)
        await asyncio.gather(*tasks)


def create_sqs(batch_conf, batch_run_id):
    sqs_name         = batch_run_id
    
    session = boto3.session.Session(
        region_name = batch_conf["region"],
        profile_name = batch_conf["profile"]
    )

    sqs = session.client('sqs')

    response = sqs.create_queue(
        QueueName = sqs_name,
    )

    sqs_url = response['QueueUrl']
    return sqs_url
 

def destroy_resources(batch_conf, sqs_url, job_defenition_arn):
    session = boto3.session.Session(
        region_name = batch_conf["region"],
        profile_name = batch_conf["profile"]
    )
    sqs = session.client('sqs')
    sqs.delete_queue(QueueUrl=sqs_url)

    batch = session.client('batch')
    batch.deregister_job_definition(
        jobDefinition = job_defenition_arn
    )


def create_batch_job_defenition(batch_conf, 
                                batch_run_id, 
                                sqs_url, 
                                child_job_image,
                                child_job_entrypoint,
                                job_outputs_s3_dir):
    
    session = boto3.session.Session(
        region_name  = batch_conf["region"],
        profile_name = batch_conf["profile"]
    )
    batch = session.client('batch')

    response = batch.register_job_definition(
        jobDefinitionName    = batch_run_id,
        type                 = 'container',
        propagateTags        = True,
        timeout              = { 'attemptDurationSeconds' : 123          },
        tags                 = { 'Name' :                   batch_run_id },
        platformCapabilities = ['EC2'],
        containerProperties  = {
            'image': batch_conf["child_wrapper_image"],
            'command': ['pipenv', 'run', 'python3.10', '-m', 'child.main'],
            'volumes': [
                {
                    'host' : { 'sourcePath': cnfg.CHILD_JOBS_INPUT_PATH },
                    'name' : cnfg.CHILD_JOBS_INPUT_VOL_NAME
                },
                { 
                    'host' : { 'sourcePath': cnfg.DOCKER_SOCK_PATH },
                    'name' : cnfg.DOCKER_SOCK_VOL_NAME
                }
            ],
            'environment': [
                { 'name': 'SQS_URL',               'value': sqs_url                       },
                { 'name': 'BATCH_RUN_ID',          'value': batch_run_id                  },
                { 'name': 'CHILDJOB_IMAGE',        'value': child_job_image               },
                { 'name': 'CHILDJOB_ENTERYPOINT',  'value': child_job_entrypoint          },
                { 'name': 'BATCH_REGION',          'value': batch_conf["region"]          },
                { 'name': 'BATCH_BUCKET',          'value': batch_conf["bucket"]          },
                { 'name': 'BATCH_OUTPUTS_S3_DIR',  'value': job_outputs_s3_dir            },
                { 'name': 'BATCH_COMPOSE_SERVICE', 'value': batch_conf["compose_service"] }
            ],
            'mountPoints': [
                {
                    'containerPath': cnfg.CHILD_JOBS_INPUT_PATH,
                    'sourceVolume': cnfg.CHILD_JOBS_INPUT_VOL_NAME,
                    'readOnly': False
                },
                {
                    'containerPath': cnfg.DOCKER_SOCK_PATH,
                    'sourceVolume': cnfg.DOCKER_SOCK_VOL_NAME,
                    'readOnly': False
                }
            ],
            'resourceRequirements': [
                { 'type': 'VCPU',   'value': str(batch_conf["vcpus_per_childjob"])     },
                { 'type': 'MEMORY', 'value': str(batch_conf["memory_mb_per_childjob"]) }
            ],
        }
    )

    return response['jobDefinitionArn']


def is_job_finished(batch_client, job_id):
    describe = batch_client.describe_jobs(jobs=[job_id])
    status   = describe['jobs'][0]['status']
    print(f"Batch status: {status}")
    return status in ['SUCCEEDED', 'FAILED']


def run_batch_job(batch_conf, batch_run_id, job_defenition_arn, timeout_seconds, num_child_jobs):

    session = boto3.session.Session(
        region_name  = batch_conf["region"],
        profile_name = batch_conf["profile"]
    )
    batch = session.client('batch')

    response = batch.submit_job(
        jobName         = batch_run_id,
        jobQueue        = batch_conf["batch_job_queue_arn"],
        jobDefinition   = job_defenition_arn,
        timeout         = { 'attemptDurationSeconds': timeout_seconds },
        arrayProperties = { 'size':                   num_child_jobs  }
    )

    job_id = response['jobId']
    print(f"Started job with ID: {job_id}")

    polling2.poll(
        lambda: is_job_finished(batch, job_id),
        step          = 10,
        timeout       = timeout_seconds,
        check_success = lambda x: x is True
    )

    return job_id


def get_index_to_child_job_name_map(batch_conf,job_outputs_s3_dir):

    mapping = {}

    session = boto3.session.Session(
        region_name  = batch_conf["region"],
        profile_name = batch_conf["profile"]
    )
    s3     = session.resource('s3')
    bucket = s3.Bucket(batch_conf["bucket"])

    for obj in bucket.objects.filter(Prefix=job_outputs_s3_dir):
        s3_object = obj.get()
        body      = s3_object['Body'].read().decode('utf-8')
        data      = json.loads(body)
        mapping.update(data)
    
    return mapping


def get_child_job_name_to_result_map(batch_conf, job_outputs_s3_dir, job_id):
    index_to_child_job_name_map = get_index_to_child_job_name_map(batch_conf, job_outputs_s3_dir)


    session = boto3.session.Session(
        region_name  = batch_conf["region"],
        profile_name = batch_conf["profile"]
    )
    batch = session.client('batch')

    successful_child_jobs = batch.list_jobs(arrayJobId=job_id,jobStatus="SUCCEEDED")["jobSummaryList"]
    failed_child_jobs     = batch.list_jobs(arrayJobId=job_id,jobStatus="FAILED")["jobSummaryList"]
    child_jobs            = successful_child_jobs + failed_child_jobs

    child_job_name_to_result_map = {}
    for child_job in child_jobs:
        child_job_index = str(child_job["arrayProperties"]["index"])
        if child_job_index in index_to_child_job_name_map.keys():
            child_job_name_to_result_map[index_to_child_job_name_map[child_job_index]] = child_job
            

    return child_job_name_to_result_map


async def run_batch(name, batch_env, child_job_image, child_inputs, child_job_entrypoint):

    args_map = locals().copy()

    print(json.dumps(args_map, indent=2))

    validator = Validator(validation.INPUTS_SCHEMA)

    if not validator.validate(args_map):
        raise Exception(f"Inputs validation failed: {validator.errors}")
    

    batch_conf_str   = utils.get_ssm_param(f"{cnfg.BATCH_ENV_SSM_PARAM_PREFIX}{batch_env}") 
    batch_conf       = json.loads(batch_conf_str)
    ecr_registry     = batch_conf["ecr_repo_url"].split("/")[0]
    profile          = batch_conf["profile"]
    region           = batch_conf["region"]
    ecr_repo_url     = batch_conf["ecr_repo_url"]
    image_tag_prefix = batch_conf["image_tag_prefix"]

    current_datetime = datetime.now()
    datetime_str     = current_datetime.strftime("%Y_%m_%d__%H_%M")
    batch_run_id     = f'{name}_{utils.generate_random_string()}_{datetime_str}'

    image_tag        = f'{image_tag_prefix}{batch_run_id}'

    
    job_artifacts_s3_dir = get_job_artifacts_s3_dir(batch_conf, batch_run_id, current_datetime)
    job_inputs_s3_dir    = f"{job_artifacts_s3_dir}/inputs"
    job_outputs_s3_dir   = f"{job_artifacts_s3_dir}/outputs"
    sqs_url              = create_sqs(batch_conf, batch_run_id)

    try:


        await upload_and_queue_child_inputs(batch_conf, 
                                            child_inputs, 
                                            sqs_url, 
                                            job_inputs_s3_dir)


        tagged_child_job_image = f'{ecr_repo_url}:{image_tag}'
        tag_and_push_image_to_ecr(profile,
                                  region,
                                  ecr_registry,
                                  child_job_image,
                                  tagged_child_job_image)
    
        job_defenition_arn = create_batch_job_defenition(batch_conf, 
                                                         batch_run_id, 
                                                         sqs_url,
                                                         tagged_child_job_image,
                                                         child_job_entrypoint,
                                                         job_outputs_s3_dir)
        
        job_id = run_batch_job(batch_conf, 
                               batch_run_id, 
                               job_defenition_arn, 
                               timeout_seconds = 3600,
                               num_child_jobs  = len(child_inputs))
        

        child_job_name_to_result_map = get_child_job_name_to_result_map(batch_conf, job_outputs_s3_dir, job_id)

        return child_job_name_to_result_map

    finally:
        destroy_resources(batch_conf, sqs_url, job_defenition_arn)
