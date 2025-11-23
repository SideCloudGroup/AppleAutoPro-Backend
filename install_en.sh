#!/bin/bash
IFS=$'\n\t'
# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ -t 0 ]; then stty erase ^H; fi

check_docker_permission() {
  current_user=$(whoami)
  if [ "$current_user" != "root" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      echo -e "${BLUE}Detected system: ${YELLOW}macOS${NC}"
      if ! docker info &>/dev/null; then
        echo -e "${RED}Cannot connect to the Docker daemon${NC}"
        echo -e "${YELLOW}Please check if Docker Desktop is installed and running!${NC}"
        echo -e "${RED}If Docker Desktop is running, try running this script as root (sudo)!${NC}"
        exit 1
      fi
    else
      echo -e "${BLUE}Detected system: ${YELLOW}Linux${NC}"
      if ! id -nG "$current_user" | grep -qw docker; then
        echo -e "${RED}Current user is not root and not in the docker group, no permission to use docker${NC}"
        echo -e "${YELLOW}Solution:${NC}"
        echo -e "1.${BLUE}Add the current user to the docker group and re-login to the terminal${YELLOW} (sudo gpasswd -a <username> docker)${NC}"
        echo -e "2.${BLUE}Run this script directly as root (sudo)!${NC}"
        exit 1
      fi
    fi
  else
    echo -e "${BLUE}Current user is: ${YELLOW}root${NC}"
  fi
}

check_docker_permission

echo -e "${GREEN}Checking if Docker is installed...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found, installing Docker...${NC}"
    docker version > /dev/null 2>&1 || curl -fsSL https://get.docker.com | bash
    systemctl enable docker && systemctl restart docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Docker installation failed. Please check for errors.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Docker installation completed.${NC}"
else
    echo -e "${GREEN}Docker is already installed.${NC}"
fi

# Default installation directory
DEFAULT_DIR="/opt/AppleAutoPro-Backend"
read -p "Enter installation directory [${DEFAULT_DIR}]: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_DIR}"
echo -e "${GREEN}Installation directory set to: ${INSTALL_DIR}${NC}"

# Create directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    chown "$(whoami):$(whoami)" "$INSTALL_DIR"
    echo -e "${GREEN}Created directory ${INSTALL_DIR}.${NC}"
fi

# Prompt for required variables
while [[ -z "${API_URL:-}" ]]; do
    read -p "Enter API URL (e.g., https://example.com): " API_URL
    if [[ -z "$API_URL" ]]; then
        echo -e "${RED}API URL cannot be empty. Please try again.${NC}"
    fi
done

while [[ -z "${API_KEY:-}" ]]; do
    read -p "Enter API Key: " API_KEY
    if [[ -z "$API_KEY" ]]; then
        echo -e "${RED}API Key cannot be empty. Please try again.${NC}"
    fi
done

while [[ -z "${NODENAME:-}" ]]; do
    read -p "Enter Node Name (identifier for this node, no non-English characters): " NODENAME
    if [[ -z "$NODENAME" ]]; then
        echo -e "${RED}Node Name cannot be empty. Please try again.${NC}"
    elif [[ ! "$NODENAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        echo -e "${RED}Node Name cannot contain non-English characters. Please try again.${NC}"
        NODENAME=""
    fi
done

read -p "Enter number of replicas (default 5): " REPLICAS
REPLICAS="${REPLICAS:-5}"

# Generate docker-compose.yml
cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
services:
  backend:
    image: pplulee/appleautopro:v4
    restart: always
    network_mode: "host"
    environment:
      - API_URL=${API_URL}
      - API_KEY=${API_KEY}
      - NODENAME=${NODENAME}
      - APP_LANG=en_us
    deploy:
      replicas: ${REPLICAS}
    logging:
      options:
        max-size: "3m"
        max-file: "2"
EOF

echo -e "${GREEN}docker-compose.yml saved to ${INSTALL_DIR}.${NC}"

cd "$INSTALL_DIR"
echo -e "${GREEN}Pulling Docker images...${NC}"
docker compose pull

echo -e "${GREEN}AppleAutoPro backend installation completed.${NC}"
echo -e "${YELLOW}To start the service, run:${NC}"
echo -e "${YELLOW}cd ${INSTALL_DIR} && docker compose up -d${NC}"
