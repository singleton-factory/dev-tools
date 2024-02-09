#!/bin/bash

# Setup FuseFS
apt clean && apt update
apt install -y fuse-overlayfs
ln -s /usr/bin/fuse-overlayfs /usr/local/bin/fuse-overlayfs

# Ensure pre-requisites are installed
apt install -y ca-certificates curl gnupg lsb-release

osID=$(env -i bash -c '. /etc/os-release; echo $ID')
osCodename=$(env -i bash -c '. /etc/os-release; echo $VERSION_CODENAME')

# Add Docker GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$osID/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Add Docker apt repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$osID $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update sources and install Docker Engine
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose