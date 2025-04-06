# Builder Stage: Install Micromamba and dependencies
FROM mambaorg/micromamba:2-cuda12.2.2-ubuntu20.04 as builder

WORKDIR /app

ENV MAMBA_ROOT_PREFIX=/opt/conda

ARG CONDA_ENV_FILE_PATH
ARG CONDA_ENV_INTERNAL_NAME
COPY ${CONDA_ENV_FILE_PATH} ./env.yml


RUN micromamba create -n ${CONDA_ENV_INTERNAL_NAME} -f ./env.yml -y
RUN micromamba clean --all -f -y
RUN find /opt/conda -type d -name "__pycache__" -exec rm -rf {} + && \
    find /opt/conda -type f -name "*.pyc" -delete

FROM nvidia/cuda:12.2.2-base-ubuntu22.04 AS runtime

COPY --from=builder /opt/conda /opt/conda
    
ARG AWS_CLI_DOWNLOAD_LINK
ARG CONDA_ENV_INTERNAL_NAME
ARG DEBIAN_FRONTEND=noninteractive

USER root

RUN apt-get update
RUN apt-get install ca-certificates curl unzip -y
RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
RUN chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update --fix-missing

RUN apt-get install \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin -y

RUN curl ${AWS_CLI_DOWNLOAD_LINK} -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

ENV PATH="/opt/conda/envs/${CONDA_ENV_INTERNAL_NAME}/bin:/opt/conda/bin:$PATH"
RUN echo "conda activate ${CONDA_ENV_INTERNAL_NAME}" >> ~/.bashrc

WORKDIR /app
COPY . /app

CMD ["bash"]
