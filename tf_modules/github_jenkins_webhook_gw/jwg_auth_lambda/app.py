import os
import hmac
import hashlib
import json
import requests
from http import HTTPStatus

import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

GITHUB_WEBHOOK_SECRET = os.environ['GITHUB_WEBHOOK_SECRET']
JENKINS_URL           = os.environ['JENKINS_URL']


SUCCESS_RESPONE       = { 'statusCode' : HTTPStatus.OK,                    'body' : 'Success' }
UNAUTHORIZED_RESPONE  = { 'statusCode' : HTTPStatus.UNAUTHORIZED,          'body' : 'Unauthorized' }
SERVER_ERROR_RESPONSE = { 'statusCode' : HTTPStatus.INTERNAL_SERVER_ERROR, 'body' : 'Error forwarding to Jenkins' }

def verify_github_signature(event):
    signature = event['headers']['X-Hub-Signature-256']
    if not signature:
        print("Missing signature")
        return False

    if not signature.startswith('sha256='):
        print("Invalid signature format")
        return False

    body = event['body']

    computed_hmac = hmac.new(key = bytes(GITHUB_WEBHOOK_SECRET, 'utf-8'), 
                             msg = bytes(body,'utf-8'), 
                             digestmod = hashlib.sha256).hexdigest()
    expected_signature = f"sha256={computed_hmac}"

    is_valid = hmac.compare_digest(signature, expected_signature)
    if not is_valid:
        print("Signature does not match")
    return is_valid


def lambda_handler(event, context):
    if not verify_github_signature(event):
        return UNAUTHORIZED_RESPONE

    # Forward the webhook to Jenkins
    headers = event['headers']
    del headers['Host']

    data = event['body'].encode('utf-8')
    endpoints = [
        "github-webhook/"
    ]

    try:

        for endpoint in endpoints:

            jenkins_target_url = f'{JENKINS_URL}/{endpoint}'

            print(f"Send github webhook message to: {jenkins_target_url}")

            response = requests.post(
                jenkins_target_url,
                data=data,
                headers=headers,
                verify=False
            )

            if response.status_code != HTTPStatus.OK:
                error_message = (f"Failure to forward the message to Jenkins:\n"
                                f"request headers: {json.dumps(headers,indent=4)}\n"
                                f"request data: {json.dumps(data,indent=4)}\n"
                                f"response status code: {response.status_code}\n"
                                f"response text: {response.text}\n")
                print(error_message)
                raise Exception(error_message)

    except Exception as e:
        print(f"Error forwarding to Jenkins: {e}")
        return SERVER_ERROR_RESPONSE

    return SUCCESS_RESPONE
