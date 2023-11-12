FROM ghcr.io/actions/actions-runner:latest

# Add PPA sources for Node.js 18
RUN curl -s https://deb.nodesource.com/setup_18.x | sudo bash

RUN sudo apt update \
 && sudo apt upgrade -y \
 && sudo apt install -y curl unzip git \
 ca-certificates software-properties-common  \
 build-essential gcc-aarch64-linux-gnu \
 nodejs

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

SHELL ["/bin/bash", "-c"]
RUN source $HOME/.cargo/env \
 && rustup target add aarch64-unknown-linux-gnu
ENV PATH="${PATH}:/home/runner/.cargo/bin"

# Validate the availability of the Rust compiler
RUN cargo

RUN sudo add-apt-repository ppa:deadsnakes/ppa \
  && sudo apt update \
  && sudo apt install -y python3.12 python3-pip

RUN echo "alias python=python3" >> "$HOME/.bashrc"

RUN python3 -m pip install --upgrade pip

RUN pip install cargo-lambda

RUN (cd /tmp && curl -OJL https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip)

RUN unzip /tmp/aws-sam-cli-linux-x86_64.zip -d /tmp/sam-installation 

RUN sudo /tmp/sam-installation/install 
RUN rm -rf /tmp/aws-sam-cli-linux-x86_64.zip /tmp/sam-installation

RUN lsb_release -a
RUN uname -m

RUN sam --version
