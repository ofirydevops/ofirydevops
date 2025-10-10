FROM python:3.10-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        certbot python3-certbot-dns-route53 \
        openjdk-17-jdk \
        less curl unzip ca-certificates gnupg lsb-release \
        && rm -rf /var/lib/apt/lists/* \
        && update-ca-certificates


# Install docker
RUN rm -f /etc/apt/sources.list.d/docker.list
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
RUN chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list

RUN apt update

RUN apt install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin


# Install pipenv ans sam cli
RUN pip3.10 install pipenv==2023.3.20 aws-sam-cli==1.135.0

# Inatall build and twine for pypi packages management
RUN pip3.10 install build==1.2.2.post1 twine==6.1.0

# Install awscli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(arch)-2.13.1.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

# Install terraform and packer

RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
        https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
RUN apt update
RUN apt install -y terraform=1.11.4-1 packer=1.9.5-1

WORKDIR /workspace
COPY ./Pipfile* /workspace/
RUN pipenv install
