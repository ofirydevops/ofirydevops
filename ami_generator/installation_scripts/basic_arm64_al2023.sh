#!/bin/bash

set -e

# Update system packages
dnf update -y
dnf upgrade -y
dnf install -y nano jq unzip telnet amazon-cloudwatch-agent \
               openssl-devel bzip2-devel libffi-devel wget tar xz-devel \
               gcc perl gcc-c++ git zlib-devel

# Add ec2-user to the Docker group
usermod -a -G docker ec2-user

# # Install Python 3.8
# dnf groupinstall -y "Development Tools"
# wget https://www.python.org/ftp/python/3.8.18/Python-3.8.18.tgz
# tar -xf Python-3.8.18.tgz
# cd Python-3.8.18
# ./configure --enable-optimizations
# make -j $(nproc)  # Use all available CPU cores for faster compilation
# make altinstall  # Installs to /usr/local/bin without overwriting system Python
# cd ..

# # Install Python 3.10
# wget https://www.python.org/ftp/python/3.10.12/Python-3.10.12.tgz
# tar -xf Python-3.10.12.tgz
# cd Python-3.10.12
# ./configure --enable-optimizations
# make -j$(nproc)
# make altinstall
# cd ..

# Install pipenv ans sam cli
pip3.9 install pipenv==2023.3.20 aws-sam-cli==1.135.0

# Install Docker Compose
curl -SL "https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# Install git-crypt
git clone https://github.com/ofiryy/git-crypt.git
cd git-crypt
make
make install
cd ..

# Install kubectl
curl -LO "https://dl.k8s.io/release/v1.27.3/bin/linux/arm64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install aws-iam-authenticator
curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/arm64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
mv ./aws-iam-authenticator /usr/local/bin/

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh || true

# Install Terraform and Packer
dnf install -y dnf-plugins-core
dnf config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
dnf install -y terraform-1.11.0 packer-1.9.1

# Install Java 17
dnf install -y java-17-amazon-corretto-headless

# Install docker driver
wget https://github.com/docker/buildx/releases/download/v0.22.0/buildx-v0.22.0.linux-arm64 -O docker-buildx
mkdir -p ~/.docker/cli-plugins
mv docker-buildx ~/.docker/cli-plugins/docker-buildx
chmod +x ~/.docker/cli-plugins/docker-buildx
docker buildx create --name docker-container --driver docker-container --bootstrap