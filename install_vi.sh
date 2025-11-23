#!/bin/bash
IFS=$'\n\t'
# Định Nghĩa Biến Màu Sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Không Màu

if [ -t 0 ]; then stty erase ^H; fi

# Phân Tích Tham Số Dòng Lệnh
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
      echo "Cách Sử Dụng: $0 [TÙY CHỌN]"
      echo "Tùy Chọn:"
      echo "  -u, --api-url URL        URL API (bắt buộc)"
      echo "  -k, --api-key KEY        Khóa API (bắt buộc)"
      echo "  -n, --nodename NAME      Tên Node (bắt buộc)"
      echo "  -r, --replicas NUM       Số lượng replica (mặc định: 5)"
      echo "  -d, --install-dir DIR     Thư mục cài đặt (mặc định: /opt/AppleAutoPro-Backend)"
      echo "  -h, --help               Hiển thị thông tin trợ giúp này"
      exit 0
      ;;
    *)
      echo -e "${RED}Tùy chọn không xác định: $1${NC}"
      echo "Sử dụng --help để xem thông tin sử dụng"
      exit 1
      ;;
  esac
done

kiem_tra_quyen_docker() {
  nguoi_dung_hien_tai=$(whoami)
  if [ "$nguoi_dung_hien_tai" != "root" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      echo -e "${BLUE}Phát Hiện Hệ Thống: ${YELLOW}macOS${NC}"
      if ! docker info &>/dev/null; then
        echo -e "${RED}Không Thể Kết Nối Đến Docker Daemon${NC}"
        echo -e "${YELLOW}Vui Lòng Kiểm Tra Docker Desktop Đã Được Cài Đặt Và Đang Chạy!${NC}"
        echo -e "${RED}Nếu Docker Desktop Đang Chạy, Hãy Thử Chạy Script Này Với Quyền Root (sudo)!${NC}"
        exit 1
      fi
    else
      echo -e "${BLUE}Phát Hiện Hệ Thống: ${YELLOW}Linux${NC}"
      if ! id -nG "$nguoi_dung_hien_tai" | grep -qw docker; then
        echo -e "${RED}Người Dùng Hiện Tại Không Phải Root Và Không Trong Nhóm Docker, Không Có Quyền Sử Dụng Docker${NC}"
        echo -e "${YELLOW}Giải Pháp:${NC}"
        echo -e "1.${BLUE}Thêm Người Dùng Hiện Tại Vào Nhóm Docker Và Đăng Nhập Lại Terminal${YELLOW} (sudo gpasswd -a <tên_người_dùng> docker)${NC}"
        echo -e "2.${BLUE}Chạy Script Này Trực Tiếp Với Quyền Root (sudo)!${NC}"
        exit 1
      fi
    fi
  else
    echo -e "${BLUE}Người Dùng Hiện Tại Là: ${YELLOW}root${NC}"
  fi
}

kiem_tra_quyen_docker

echo -e "${GREEN}Đang Kiểm Tra Docker Đã Được Cài Đặt Chưa...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Không Tìm Thấy Docker, Đang Cài Đặt Docker...${NC}"
    docker version > /dev/null 2>&1 || curl -fsSL https://get.docker.com | bash
    systemctl enable docker && systemctl restart docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}Cài Đặt Docker Thất Bại. Vui Lòng Kiểm Tra Lỗi.${NC}"
        exit 1
    fi
    echo -e "${GREEN}Cài Đặt Docker Hoàn Tất.${NC}"
else
    echo -e "${GREEN}Docker Đã Được Cài Đặt.${NC}"
fi

# Thư Mục Cài Đặt Mặc Định
DEFAULT_DIR="/opt/AppleAutoPro-Backend"
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_DIR}"
echo -e "${GREEN}Thư Mục Cài Đặt Được Đặt Thành: ${INSTALL_DIR}${NC}"

# Tạo Thư Mục Nếu Không Tồn Tại
if [ ! -d "$INSTALL_DIR" ]; then
    mkdir -p "$INSTALL_DIR"
    chown "$(whoami):$(whoami)" "$INSTALL_DIR"
    echo -e "${GREEN}Đã Tạo Thư Mục ${INSTALL_DIR}.${NC}"
fi

# Yêu Cầu Nhập Các Biến Cần Thiết
while [[ -z "${API_URL:-}" ]]; do
    read -p "Nhập API URL (ví dụ: https://example.com): " API_URL
    if [[ -z "$API_URL" ]]; then
        echo -e "${RED}API URL Không Được Để Trống. Vui Lòng Thử Lại.${NC}"
    fi
done

while [[ -z "${API_KEY:-}" ]]; do
    read -p "Nhập API Key: " API_KEY
    if [[ -z "$API_KEY" ]]; then
        echo -e "${RED}API Key Không Được Để Trống. Vui Lòng Thử Lại.${NC}"
    fi
done

if [[ -n "${NODENAME:-}" ]] && [[ ! "$NODENAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
  echo -e "${RED}Tên Node Không Được Chứa Ký Tự Không Phải Tiếng Anh. Vui Lòng Thử Lại.${NC}"
  NODENAME=""
fi

while [[ -z "${NODENAME:-}" ]]; do
    read -p "Nhập Tên Node (định danh cho node này, không được chứa ký tự không phải tiếng Anh): " NODENAME
    if [[ -z "$NODENAME" ]]; then
        echo -e "${RED}Tên Node Không Được Để Trống. Vui Lòng Thử Lại.${NC}"
    elif [[ ! "$NODENAME" =~ ^[a-zA-Z0-9_.-]+$ ]]; then
        echo -e "${RED}Tên Node Không Được Chứa Ký Tự Không Phải Tiếng Anh. Vui Lòng Thử Lại.${NC}"
        NODENAME=""
    fi
done

if [[ -z "${REPLICAS:-}" ]]; then
  read -p "Nhập Số Lượng Replica (mặc định 5): " REPLICAS
  REPLICAS="${REPLICAS:-5}"
fi

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
      - APP_LANG=vi_vn
    deploy:
      replicas: ${REPLICAS}
    logging:
      options:
        max-size: "3m"
        max-file: "2"
EOF

echo -e "${GREEN}docker-compose.yml đã được lưu vào ${INSTALL_DIR}.${NC}"

cd "$INSTALL_DIR"
echo -e "${GREEN}Đang Tải Hình Ảnh Docker...${NC}"
docker compose pull

echo -e "${GREEN}Cài Đặt AppleAutoPro Backend Hoàn Tất.${NC}"
echo -e "${YELLOW}Để Khởi Động Dịch Vụ, Chạy Lệnh:${NC}"
echo -e "${YELLOW}cd ${INSTALL_DIR} && docker compose up -d${NC}"
