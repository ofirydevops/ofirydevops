# Builder stage: Install Conda and dependencies
FROM continuumio/miniconda3:23.3.1-0 AS builder

# Install system certificates to fix SSL issues
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Ensure Conda trusts the system certificates
RUN conda config --set ssl_verify false

# Install Mamba with a fixed version
RUN conda install -n base -c conda-forge mamba=1.4.9 && conda clean --all -f -y

#Install yq (yaml parser)
RUN wget https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64 -O /usr/bin/yq && \
    chmod +x /usr/bin/yq

# Copy the Conda environment file
ARG CONDA_ENV_FILE=data_science/conda_envs/ofirys_env.yaml
COPY ${CONDA_ENV_FILE} /tmp/environment.yml

# Create a Conda environment with fixed dependencies
RUN mamba env create -f /tmp/environment.yml --freeze-installed && \
    conda clean --all -f -y && \
    rm -rf /tmp/environment.yml

# Set Conda environment name
ENV CONDA_ENV_NAME=ofiry
ENV PATH="/opt/conda/envs/$CONDA_ENV_NAME/bin:/opt/conda/bin:$PATH"

# Remove unnecessary files to reduce image size
RUN conda env export -n $CONDA_ENV_NAME | grep -v "prefix:" > /tmp/environment.yml && \
    conda remove -n base --all --yes && \
    conda clean --all -f -y && \
    find /opt/conda -type d -name "__pycache__" -exec rm -rf {} + && \
    find /opt/conda -type f -name "*.pyc" -delete

# # Use CUDA runtime image to keep final image small
# FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04 AS runtime

# # Copy Miniconda and installed Conda environment from the builder stage
# COPY --from=builder /opt/conda /opt/conda

# # Set paths and activate Conda environment
# ENV PATH="/opt/conda/envs/ofiry/bin:/opt/conda/bin:$PATH"
# RUN echo "conda activate ofiry" >> ~/.bashrc

# CMD ["bash"]



