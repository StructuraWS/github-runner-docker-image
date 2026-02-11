#!/usr/bin/env bash
ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')"
echo arch $ARCH

if [ "$ARCH" == "arm64" ]; then
  THEARCH='linux-arm64'
else 
  THEARCH='linux-x86_64'
fi

(cd /tmp && curl -OJL https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-$THEARCH.zip)

unzip /tmp/aws-sam-cli-$THEARCH.zip -d /tmp/sam-installation 

/tmp/sam-installation/install
rm -rf /tmp/aws-sam-cli-$THEARCH.zip /tmp/sam-installation

# this fails when built on an aarch64 machine, but succeeds when built on an x86_64 machine
sam --version
