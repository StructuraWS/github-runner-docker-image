# bumped on 2025-10-30
# current version of the actions runner is 2.325.0
# current version of rust is 1.90.0
FROM ghcr.io/actions/actions-runner:latest

# FROM summerwind/actions-runner-dind:latest
# WORKDIR /tmp

RUN sudo apt update && sudo apt install -y curl software-properties-common curl gnupg ca-certificates

# update npm
RUN sudo mkdir -p /etc/apt/keyrings
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
ENV NODE_MAJOR=20
RUN echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list

RUN sudo add-apt-repository ppa:deadsnakes/ppa \
  && sudo apt update \
  && sudo apt upgrade -y \
  && sudo apt install -y python3 python3-pip \
  && sudo apt install -y unzip git libssl-dev build-essential jq \
  # for cross compiling rust binaries to aarch64/arm64
  build-essential gcc-aarch64-linux-gnu \
  # for building rust binaries for windows
  gcc-mingw-w64 \
  # for sccache \
  pkg-config libssl-dev \
  # for improved performance of building binaries with linux
  # lld clang \
  nodejs

# current version of rustc is 1.81.0
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

SHELL ["/bin/bash", "-c"]
RUN source $HOME/.cargo/env \
  && rustup target add aarch64-unknown-linux-gnu x86_64-pc-windows-gnu \
  && rustup self update \
  && rustup update

SHELL ["/bin/sh", "-c"]

# add modules installed with pip to PATH
ENV PATH="${PATH}:/home/runner/.cargo/bin:/home/runner/.local/bin:/home/runner/.local/bin:/usr/local/bin"

# Validate the availability of cargo and install cargo audit
RUN cargo install cargo-audit 

RUN cargo install sccache

# cargo nextest
RUN curl -LsSf https://get.nexte.st/latest/linux | tar zxf - -C ${CARGO_HOME:-~/.cargo}/bin

RUN echo "alias python=python3" >> "$HOME/.bashrc"

RUN python3 -m pip install --upgrade pip

RUN pip3 install --upgrade cargo-lambda

COPY install-aws-sam-cli.sh /tmp/install-aws-sam-cli.sh
RUN bash /tmp/install-aws-sam-cli.sh

# ENV PB_REL="https://github.com/protocolbuffers/protobuf/releases"
# RUN curl -LO $PB_REL/download/v25.1/protoc-25.1-linux-x86_64.zip && \
#   sudo unzip protoc-25.1-linux-x86_64.zip -d /usr/local && \
#   rm protoc-25.1-linux-x86_64.zip

COPY download-protoc.sh /tmp/download-protoc.sh
RUN sudo bash /tmp/download-protoc.sh

RUN sudo npm install -g npm@latest pnpm
RUN pnpm version

USER runner

# add modules installed with pip to PATH
ENV PATH="${PATH}:/home/runner/.cargo/bin:/home/runner/.local/bin:/home/runner/.local/bin:/usr/local/bin"

# test availability of sccache as runner user
RUN which sccache

# test availability of cargo-lambda
RUN cargo lambda

