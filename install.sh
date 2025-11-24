#!/bin/bash
IFS=$'\n\t'
# 定义颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # 无颜色
if [ -t 0 ]; then stty erase ^H; fi

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case $1 in
    --api-url|-u)
      API_URL="$2"
      shift 2
      ;;
    --api-key|-k)
      API_KEY="$2"
      shift 2
      ;;
    --nodename|-n)
      NODENAME="$2"
      shift 2
      ;;
    --replicas|-r)
      REPLICAS="$2"
      shift 2
      ;;
    --install-dir|-d)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --help|-h)
      echo "用法: $0 [选项]"
      echo "选项:"
      echo "  -u, --api-url URL         API地址（必需）"
      echo "  -k, --api-key KEY         API密钥（必需）"
      echo "  -n, --nodename NAME       节点名称（必需）"
      echo "  -r, --replicas NUM        进程数量（默认: 5）"
      echo "  -d, --install-dir DIR     安装目录（默认: /opt/AppleAutoPro-Backend）"
      echo "  -h, --help                显示此帮助信息"
      exit 0
      ;;
    *)
      echo -e "${RED}未知参数: $1${NC}"
      echo "使用 --help 查看帮助信息"
      exit 1
      ;;
  esac
done

check_docker_permission() {
  current_user=$(whoami)
  if [ "$current_user" != "root" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      echo -e "${BLUE}已检测到系统为${YELLOW}macOS${NC}"
      if ! docker info &>/dev/null; then
        echo -e "${RED}当前无法连接到Docker进程${NC}"
        echo -e "${YELLOW}请检查是否已安装Docker Desktop以及Docker Desktop服务是否已启动！${NC}"
        echo -e "${RED}如果您确信Docker Desktop已在运行，请尝试使用root(sudo)运行此脚本！${NC}"
        exit 1
      fi
    else
      echo -e "${BLUE}已检测到系统为${YELLOW}Linux${NC}"
      if ! id -nG "$current_user" | grep -qw docker; then
        echo -e "${RED}当前用户非root且不在docker用户组中，没有使用docker的权限${NC}"
        echo -e "${YELLOW}解决方法：${NC}"
        echo -e "1.${BLUE}将当前用户加入docker用户组并重新进入终端${YELLOW}(sudo gpasswd -a 用户名 docker)${NC}"
        echo -e "2.${BLUE}直接使用root(sudo)运行此脚本！${NC}"
        exit 1
      fi
    fi
  else
    echo -e "${BLUE}已检测到当前用户为${YELLOW}root${NC}"
  fi
}
check_docker_permission
geo_check() {
    api_list=(
        "https://cloudflare.com/cdn-cgi/trace"
        "https://blog.cloudflare.com/cdn-cgi/trace"
        "https://dash.cloudflare.com/cdn-cgi/trace"
        "https://developers.cloudflare.com/cdn-cgi/trace"
    )
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    isCN="false"
    for url in "${api_list[@]}"; do
        text="$(curl -A "$ua" -m 10 -sSL "$url" 2>/dev/null)" || continue
        [ -z "$text" ] && continue
        location="$(echo "$text" | grep '^loc=' | cut -d'=' -f2)"
        if [ -n "$location" ]; then
            if [ "$location" = "CN" ]; then
                isCN="true"
            else
                isCN="false"
            fi
            break
        else
            if echo "$text" | grep -q 'loc=CN'; then
                isCN="true"
                break
            fi
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
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_DIR}"
echo -e "${GREEN}安装目录设置为: ${INSTALL_DIR}${NC}"

if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    chown $(whoami):$(whoami) "$INSTALL_DIR"
    echo -e "${GREEN}目录 ${INSTALL_DIR} 创建完成。${NC}"
fi

while [[ -z "${API_URL:-}" ]]; do
  read -p "请输入网站地址（格式 http[s]://xxx.xxx）: " API_URL
  if [[ -z "$API_URL" ]]; then
    echo -e "${RED}网站地址不能为空，请重新输入。${NC}"
  fi
done

while [[ -z "${API_KEY:-}" ]]; do
  read -p "请输入 API Key: " API_KEY
  if [[ -z "$API_KEY" ]]; then
    echo -e "${RED}API Key 不能为空，请重新输入。${NC}"
  fi
done

if [[ -n "${NODENAME:-}" ]] && [[ ! "$NODENAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
  echo -e "${RED}节点名称不能包含非英文字符，请重新输入。${NC}"
  NODENAME=""
fi

while [[ -z "${NODENAME:-}" ]]; do
  read -p "请输入节点名称（用于标识当前节点，不要出现非英文字符）: " NODENAME
  if [[ -z "$NODENAME" ]]; then
    echo -e "${RED}节点名称不能为空，请重新输入。${NC}"
  elif [[ ! "$NODENAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
    echo -e "${RED}节点名称不能包含非英文字符，请重新输入。${NC}"
    NODENAME=""
  fi
done

if [[ -z "${REPLICAS:-}" ]]; then
  read -p "请输入进程数量（默认5）: " REPLICAS
  REPLICAS=${REPLICAS:-5}
fi

cat > "$INSTALL_DIR/docker-compose.yml" <<EOF
services:
  backend:
    image: pplulee/appleautopro:v4
    restart: unless-stopped
    environment:
      - API_URL=${API_URL}
      - API_KEY=${API_KEY}
      - NODENAME=${NODENAME}
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
