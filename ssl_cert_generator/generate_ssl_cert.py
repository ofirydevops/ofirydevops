import os
import subprocess
from pylib.ofirydevops.utils import main as utils

SSL_GENERATION_SCRIPT = "./ssl_cert_generator/generate_ssl_cert.sh"


def create_ssl_cert():
    session         = utils.get_boto3_session()
    credentials     = session.get_credentials()
    profile, region = utils.get_profile_and_region()
    namespace       = utils.get_namespace()
    email           = utils.get_ssm_param(f"/{namespace}/secrets/email")
    domain          = utils.get_ssm_param(f"/{namespace}/secrets/domain")

    os.environ["NAMESPACE"]             = namespace
    os.environ["DOMAIN"]                = domain
    os.environ["EMAIL"]                 = email
    os.environ["AWS_REGION"]            = region
    os.environ["AWS_ACCESS_KEY_ID"]     = credentials.access_key
    os.environ["AWS_SECRET_ACCESS_KEY"] = credentials.secret_key
    if credentials.token != None:
        os.environ["AWS_SESSION_TOKEN"] = credentials.token

    subprocess.run(SSL_GENERATION_SCRIPT, check=True, shell=True)

    

def main():
    create_ssl_cert()

if __name__ == "__main__":
    main()

