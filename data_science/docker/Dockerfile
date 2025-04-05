# Builder stage: Install Conda and dependencies
FROM continuumio/miniconda3:23.3.1-0 AS builder

# Install system certificates to fix SSL issues
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Ensure Conda trusts the system certificates
RUN conda config --set ssl_verify false

# Install Mamba with a fixed version
RUN conda install -n base -c conda-forge mamba=1.4.9 && conda clean --all -f -y

# Copy the Conda environment file
ARG CONDA_ENV_FILE_PATH
ARG CONDA_ENV_INTERNAL_NAME
COPY ${CONDA_ENV_FILE_PATH} ./env.yml

# Create a Conda environment with fixed dependencies

RUN mamba env create --name $CONDA_ENV_INTERNAL_NAME -f ./env.yml
RUN conda clean --all -f -y

# Set Conda environment name

ENV PATH="/opt/conda/envs/$CONDA_ENV_INTERNAL_NAME/bin:/opt/conda/bin:$PATH"

# Remove unnecessary files to reduce image size
RUN conda run -n ${CONDA_ENV_INTERNAL_NAME} conda env export | grep -v "prefix:" > ./env.yml && \
    conda clean --all -f -y && \
    find /opt/conda -type d -name "__pycache__" -exec rm -rf {} + && \
    find /opt/conda -type f -name "*.pyc" -delete

# Use CUDA runtime image to keep final image small
FROM nvidia/cuda:12.2.2-base-ubuntu22.04 AS runtime

ARG CONDA_ENV_INTERNAL_NAME
ARG AWS_CLI_DOWNLOAD_LINK
# Copy Miniconda and installed Conda environment from the builder stage
COPY --from=builder /opt/conda /opt/conda
# Add Docker's official GPG key:
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
RUN apt-get update

RUN apt-get install \
        docker-ce=5:28.0.4-1~ubuntu.22.04~jammy \
        docker-ce-cli=5:28.0.4-1~ubuntu.22.04~jammy \
        containerd.io=1.7.27-1 \
        docker-buildx-plugin=0.22.0-1~ubuntu.22.04~jammy \
        docker-compose-plugin=2.34.0-1~ubuntu.22.04~jammy -y


RUN curl ${AWS_CLI_DOWNLOAD_LINK} -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install


# Set paths and activate Conda environment
ENV PATH="/opt/conda/envs/${CONDA_ENV_INTERNAL_NAME}/bin:/opt/conda/bin:$PATH"
RUN echo "conda activate ${CONDA_ENV_INTERNAL_NAME}" >> ~/.bashrc

# Copy all code into image
WORKDIR /app
COPY . /app

CMD ["bash"]

FROM runtime AS remote_dev

RUN apt-get install openssh-server sudo make g++ libssl-dev -y && \
    mkdir -p /run/sshd && \
    chmod 755 /run/sshd
EXPOSE 22

ARG USER=root 
ARG HOME=/${USER}

RUN mkdir -p ${HOME}/.ssh \
    && chown ${USER}:${USER} ${HOME}/.ssh \
    && chmod 700 ${HOME}/.ssh

COPY data_science/docker/remote/authorized_keys ${HOME}/.ssh/authorized_keys

RUN chown ${USER}:${USER} ${HOME}/.ssh/authorized_keys && \
    chmod 600 ${HOME}/.ssh/authorized_keys

RUN echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

RUN cd ${HOME} && \
    git clone https://github.com/ofiryy/git-crypt.git && \
    cd git-crypt && \
    make && \
    make install

RUN git-crypt lock || true

ARG GIT_REF
RUN git remote set-url origin https://github.com/ofiryy/devops-project.git
RUN git config --global user.name "remote-user"
RUN git config --global user.email @
RUN git checkout $GIT_REF

CMD ["/usr/sbin/sshd", "-D"]