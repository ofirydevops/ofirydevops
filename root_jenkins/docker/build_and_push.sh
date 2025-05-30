aws ecr get-login-password --region ${REGION} --profile ${PROFILE} | \
    docker login --username AWS --password-stdin ${DOCKER_REGISTRY}
docker compose -f ${MODULE_PATH}/../docker/docker-compose.yml build main -q
docker compose -f ${MODULE_PATH}/../docker/docker-compose.yml push main -q