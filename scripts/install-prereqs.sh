#!/bin/bash
set -e

# Support only Ubuntu/Debian logic as requested
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}Starting infrastructure tools installation (Ubuntu/Debian)...${NC}"

# Update package index
sudo apt-get update

# 1. Install Docker
if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}Installing Docker...${NC}"
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    sudo systemctl start docker || true
    sudo systemctl enable docker || true
    sudo usermod -aG docker $USER
    newgrp docker
    echo "Docker installed."
else
    echo "Docker is already installed."
fi

# 2. Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${GREEN}Installing kubectl...${NC}"
    sudo apt-get install -y apt-transport-https
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt-get update
    sudo apt-get install -y kubectl
else
    echo "kubectl is already installed."
fi

# 3. Install kind
if ! command -v kind &> /dev/null; then
    echo -e "${GREEN}Installing kind...${NC}"
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
else
    echo "kind is already installed."
fi

# 4. Install Helm
if ! command -v helm &> /dev/null; then
    echo -e "${GREEN}Installing Helm...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "Helm is already installed."
fi

# 5. Install AWS CLI (v2)
if ! command -v aws &> /dev/null; then
    echo -e "${GREEN}Installing AWS CLI...${NC}"
    sudo apt-get install -y unzip
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf aws awscliv2.zip
else
    echo "AWS CLI is already installed."
fi

echo -e "${GREEN}Installation complete! verify with:${NC}"
echo "docker --version"
echo "kubectl version --client"
echo "kind version"
echo "helm version"
echo "aws --version"
