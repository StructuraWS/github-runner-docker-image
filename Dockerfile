FROM ghcr.io/actions/actions-runner:latest

# Add PPA sources for Node.js 18
RUN curl -s https://deb.nodesource.com/setup_18.x | sudo bash

RUN sudo apt update \
 && sudo apt upgrade -y \
 && sudo apt install -y curl unzip git libssl-dev \
 ca-certificates software-properties-common  \
 # for cross compiling rust binaries to aarch64/arm64
 build-essential gcc-aarch64-linux-gnu \
 # for building rust binaries for windows
 gcc-mingw-w64 \
 nodejs

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

SHELL ["/bin/bash", "-c"]
RUN source $HOME/.cargo/env \
 && rustup target add aarch64-unknown-linux-gnu x86_64-pc-windows-gnu \
 && rustup self update \
 && rustup update
ENV PATH="${PATH}:/home/runner/.cargo/bin"

# Validate the availability of cargo
RUN cargo

RUN sudo add-apt-repository ppa:deadsnakes/ppa \
  && sudo apt update \
  && sudo apt install -y python3.12 python3-pip

RUN echo "alias python=python3" >> "$HOME/.bashrc"

RUN python3 -m pip install --upgrade pip

RUN pip3 install cargo-lambda

# add modules installed with pip to PATH
ENV PATH="${PATH}:/home/runner/.local/bin"

# test availability of cargo-lambda
RUN cargo lambda

RUN (cd /tmp && curl -OJL https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip)

RUN unzip /tmp/aws-sam-cli-linux-x86_64.zip -d /tmp/sam-installation 

RUN sudo /tmp/sam-installation/install 
RUN rm -rf /tmp/aws-sam-cli-linux-x86_64.zip /tmp/sam-installation

# this fails when built on an aarch64 machine, but succeeds when built on an x86_64 machine
RUN sam --version
