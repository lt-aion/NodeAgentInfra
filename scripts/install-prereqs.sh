#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting infrastructure tools installation...${NC}"

# 1. Install Docker (Fedora/RHEL/CentOS specific, generic fallback)
if ! command -v docker &> /dev/null; then
    echo -e "${GREEN}Installing Docker...${NC}"
    if [ -f /etc/fedora-release ]; then
        sudo dnf -y install dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo usermod -aG docker $USER
        echo "Docker installed. Please log out and back in to use Docker without sudo."
    else
        echo "Please install Docker manually for your distribution: https://docs.docker.com/engine/install/"
    fi
else
    echo "Docker is already installed."
fi

# 2. Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${GREEN}Installing kubectl...${NC}"
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl
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

echo -e "${GREEN}Installation complete! verify with:${NC}"
echo "docker --version"
echo "kubectl version --client"
echo "kind version"
echo "helm version"
