#!/bin/bash
IFS=$'\n\t'

# Define color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Only set erase character if running in a terminal
if [ -t 0 ]; then stty erase ^H; fi

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

while [[ -z "${REDIS_HOST:-}" ]]; do
    read -p "Enter Redis host (e.g., 127.0.0.1): " REDIS_HOST
    if [[ -z "$REDIS_HOST" ]]; then
        echo -e "${RED}Redis host cannot be empty. Please try again.${NC}"
    fi
done

while [[ -z "${REDIS_PORT:-}" ]]; do
    read -p "Enter Redis port (default 6379): " REDIS_PORT
    if [[ -z "$REDIS_PORT" ]]; then
        echo -e "${RED}Redis port cannot be empty. Please try again.${NC}"
    fi
done

read -p "Enter number of replicas (default 5): " REPLICAS
REPLICAS="${REPLICAS:-5}"

# Generate docker-compose.yml
cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
version: "3"
services:
  backend:
    image: pplulee/appleautopro:v4
    restart: always
    environment:
      - API_URL=${API_URL}
      - API_KEY=${API_KEY}
      - REDIS_HOST=${REDIS_HOST}
      - REDIS_PORT=${REDIS_PORT}
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
