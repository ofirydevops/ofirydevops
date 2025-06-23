#!/bin/bash

set -e

aws codeartifact login \
   --tool twine \
   --domain ${CODEARTIFACT_DOMAIN} \
   --domain-owner ${CODEARTIFACT_DOMAIN_OWNER} \
   --repository ${CODEARTIFACT_REPO} \
   --region ${REGION} \
   --profile ${PROFILE}


cd ${PACKAGE_DIR}
pip3.10 list
python3.10 -m build
twine upload --repository codeartifact dist/*