#!/bin/bash

set -e

CURRENT_DRIVER=$(docker buildx ls | grep '\*' | awk '{print $1}' | sed 's/\*//')

docker run --privileged --rm tonistiigi/binfmt --install all

docker buildx create --name multiarch-builder || true
docker buildx use multiarch-builder 
docker buildx inspect --bootstrap

aws ecr get-login-password --region ${REGION} --profile ${PROFILE} | \
    docker login --username AWS --password-stdin ${DOCKER_REGISTRY}

docker buildx bake -f ${DOCKER_COMPOSE_PATH} --push --set *.platform=linux/${ARCH}

docker buildx use ${CURRENT_DRIVER}
