#!/bin/bash
IFS=$'\n\t'
# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色
if [ -t 0 ]; then stty erase ^H; fi
geo_check() {
    api_list="https://blog.cloudflare.com/cdn-cgi/trace https://dash.cloudflare.com/cdn-cgi/trace https://developers.cloudflare.com/cdn-cgi/trace"
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    isCN="false"
    for url in $api_list; do
        text="$(curl -A "$ua" -m 10 -s "$url")"
        endpoint="$(echo "$text" | sed -n 's/.*h=\([^ ]*\).*/\1/p')"
        if echo "$text" | grep -qw 'CN'; then
            isCN="true"
            break
        elif echo "$url" | grep -q "$endpoint"; then
            isCN="false"
            break
        fi
    done
}
geo_check

echo -e "${GREEN}正在检查 Docker 是否安装...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker 未安装，开始安装 Docker...${NC}"
    if [ "$isCN" = "true" ]; then
            bash <(curl -sSL https://linuxmirrors.cn/docker.sh) --source-registry "https://docker.1panel.live" --install-latest true --ignore-backup-tips
        else
            docker version > /dev/null || curl -fsSL get.docker.com | bash
            systemctl enable docker && systemctl restart docker
    fi
    if ! docker >/dev/null 2>&1; then
        echo "Docker安装失败，请检查错误信息"
        exit 1
    fi
    echo -e "${GREEN}Docker 安装完成。${NC}"
else
    echo -e "${GREEN}Docker 已安装。${NC}"
fi

DEFAULT_DIR="/opt/AppleAutoPro-Backend"
read -p "请输入安装目录 [${DEFAULT_DIR}]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}
echo -e "${GREEN}安装目录设置为: ${INSTALL_DIR}${NC}"

if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    chown $(whoami):$(whoami) "$INSTALL_DIR"
    echo -e "${GREEN}目录 ${INSTALL_DIR} 创建完成。${NC}"
fi

while [[ -z "$API_URL" ]]; do
  read -p "请输入网站地址（格式 http[s]://xxx.xxx）: " API_URL
  if [[ -z "$API_URL" ]]; then
    echo -e "${RED}网站地址不能为空，请重新输入。${NC}"
  fi
done

while [[ -z "$API_KEY" ]]; do
  read -p "请输入 API Key: " API_KEY
  if [[ -z "$API_KEY" ]]; then
    echo -e "${RED}API Key 不能为空，请重新输入。${NC}"
  fi
done

while [[ -z "$REDIS_HOST" ]]; do
  read -p "请输入 Redis主机地址（通常为前端服务器IP）: " REDIS_HOST
  if [[ -z "$REDIS_HOST" ]]; then
    echo -e "${RED}Redis主机地址不能为空，请重新输入。${NC}"
  fi
done

while [[ -z "$REDIS_PORT" ]]; do
  read -p "请输入 Redis端口（通常为6379）: " REDIS_PORT
  if [[ -z "$REDIS_PORT" ]]; then
    echo -e "${RED}Redis端口不能为空，请重新输入。${NC}"
  fi
done

read -p "请输入进程数量（默认5）: " REPLICAS
REPLICAS=${REPLICAS:-5}

cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
version: "3"
services:
  backend:
    image: pplulee/appleautopro:v4
    restart: always
    network_mode: "host"
    environment:
      - API_URL=${API_URL}
      - API_KEY=${API_KEY}
      - REDIS_HOST=${REDIS_HOST}
      - REDIS_PORT=${REDIS_PORT}
      - APP_LANG=zh_cn
    deploy:
      replicas: ${REPLICAS}
    logging:
      options:
        max-size: "3m"
        max-file: "2"
EOF

echo -e "${GREEN}docker-compose.yml 已保存到 ${INSTALL_DIR}${NC}"

cd "$INSTALL_DIR"
echo -e "${GREEN}正在拉取镜像...${NC}"
docker compose pull

echo -e "${GREEN}AppleAutoPro 后端服务安装完成。${NC}"
echo -e "${YELLOW}请前往安装目录 ${INSTALL_DIR} 启动服务：${NC}"
echo -e "${YELLOW}cd ${INSTALL_DIR} && docker compose up -d${NC}"
