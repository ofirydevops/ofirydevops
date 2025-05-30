FROM python:3.10-slim

RUN apt update
RUN apt install -y ca-certificates curl gnupg lsb-release unzip

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

# Install pipenv
RUN pip3.10 install pipenv==2023.3.20

# Install awscli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-$(arch)-2.13.1.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install

WORKDIR /workspace
COPY Pipfile* /workspace/
COPY ./batch_runner /workspace/batch_runner
RUN pipenv install && cat Pipfile.lock
