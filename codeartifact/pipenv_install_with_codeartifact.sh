#!/bin/bash

## Set the CODEARTIFACT_URL env var, so that Pipfile could be installed with a codeartifact source.
## Pipfile example:

# [[source]]
# name = "pypi"
# url = "https://pypi.org/simple"
# verify_ssl = true

# [[source]]
# name = "codeartifact"
# url  = "${CODEARTIFACT_URL}"
# verify_ssl = true

# [packages]
# boto3 = "==1.37.3"
# aws-batch-runner = { version = "==0.1.0", index = "codeartifact" }


## Call example: 
# source ./codeartifact/pipenv_install_with_codeartifact.sh eu-central-1 OFIRYDEVOPS /codeartifact/batch_runner_main
# pipenv install

set -e

REGION=$1
PROFILE=$2
CODEARTIFACT_CONF_SSM_PARAM=$3

info=$(aws ssm get-parameter \
  --name "$CODEARTIFACT_CONF_SSM_PARAM" \
  --with-decryption \
  --query "Parameter.Value" \
  --output text --region ${REGION} --profile ${PROFILE})


domain=$(echo  "$info" | jq -r '.domain')
owner=$(echo   "$info" | jq -r '.owner')
repo=$(echo    "$info" | jq -r '.repo')
region=$(echo  "$info" | jq -r '.region')
profile=$(echo "$info" | jq -r '.profile')


export CODEARTIFACT_AUTH_TOKEN=$(aws codeartifact get-authorization-token \
  --domain $domain \
  --domain-owner $owner \
  --region $region \
  --query authorizationToken --output text --profile $profile)

export CODEARTIFACT_URL="https://aws:${CODEARTIFACT_AUTH_TOKEN}@${domain}-${owner}.d.codeartifact.${region}.amazonaws.com/pypi/${repo}/simple/"

pipenv install