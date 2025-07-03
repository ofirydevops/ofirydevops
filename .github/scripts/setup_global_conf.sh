#!/bin/bash

set -e

GLOBAL_CONF_FILE="pylib/ofirydevops/global_conf.yaml"

PROFILE=$1
REGION=$2
NAMESPACE=$3

cat > ${GLOBAL_CONF_FILE} <<EOF
profile: ${PROFILE}
region: ${REGION}
namespace: ${NAMESPACE}
EOF
cat ${GLOBAL_CONF_FILE}
