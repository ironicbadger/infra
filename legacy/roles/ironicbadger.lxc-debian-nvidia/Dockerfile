FROM debian:12.7-slim

ARG NVIDIA_DRIVER_VERSION

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    wget \
    pv \
    tar \
    gzip \
    debootstrap \
    sudo \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create template directory
WORKDIR /template

# Copy setup script
COPY scripts/setup_template.sh /template/
COPY scripts/create_template.sh /template/

# Make scripts executable
RUN chmod +x /template/setup_template.sh /template/create_template.sh

# Build the template - use a default driver version if none is specified
RUN /template/create_template.sh ${NVIDIA_DRIVER_VERSION:-550.144.03}