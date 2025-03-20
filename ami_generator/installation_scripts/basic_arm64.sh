#!/bin/bash

set -e

yum update -y
yum upgrade -y
yum install nano jq unzip telnet amazon-cloudwatch-agent -y
yum install openssl-devel bzip2-devel libffi-devel wget tar xz-devel gcc perl -y

# Add ec2-user to the Docker group
usermod -a -G docker ec2-user

# Install openssl 1.1.1u
yum install -y openssl openssl-devel
cd /usr/local/src
wget https://www.openssl.org/source/openssl-1.1.1u.tar.gz
tar -xvzf openssl-1.1.1u.tar.gz
cd openssl-1.1.1u
./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
make
make install
ln -sf /usr/local/openssl/bin/openssl /usr/bin/openssl
echo "/usr/local/openssl/lib" | tee /etc/ld.so.conf.d/openssl.conf
ldconfig -v
cd ~

# Install python3.8
amazon-linux-extras enable python3.8
yum install python3.8 -y
# yum install libpq-dev -y
yum install postgresql-devel -y
yum install python3-devel -y
yum install python38-devel -y
ln -s -f /usr/bin/python3.8 /usr/bin/python3
pip3.8 install aws-sam-cli==1.89.0

# Install python3.10
yum groupinstall "Development Tools" -y
wget https://www.python.org/ftp/python/3.10.12/Python-3.10.12.tgz
tar -xf Python-3.10.12.tgz
cd Python-3.10.12
./configure --enable-optimizations --with-openssl=/usr/local/openssl
make -j $(nproc)
sudo make altinstall
cd ..
/usr/local/bin/pip3.10 install pipenv==2023.3.20

# Install docker compose
curl -SL "https://github.com/docker/compose/releases/download/v2.32.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
chmod +x /usr/libexec/docker/cli-plugins/docker-compose

# Install git-crypt
yum install git -y
yum install -y gcc-c++
yum install openssl-devel -y
git clone https://github.com/AGWA/git-crypt.git
cd git-crypt
make
make install
cd ..

# Install kubectl
curl -LO "https://dl.k8s.io/release/v1.27.3/bin/linux/arm64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install aws-iam-authenticator
curl -Lo aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.15.10/2020-02-22/bin/linux/arm64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
mv ./aws-iam-authenticator /usr/local/bin/

# Install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh || true

# Install terraform and packer
yum install -y yum-utils
yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
yum -y install terraform-1.11.0 packer-1.9.1

# Install awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-2.13.1.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

cp -f /usr/local/bin/{kubectl,aws-iam-authenticator,helm,git-crypt} /usr/bin/

# Install java17
yum install java-17-amazon-corretto-headless -y