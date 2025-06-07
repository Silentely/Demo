# 脚本名称: install-latest-fastfetch.sh
# 功能: 从 GitHub 下载并安装最新版的 fastfetch (.deb 包)
#!/bin/bash

# --- 颜色和表情符号定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 当脚本遇到错误时，调用此函数
handle_error() {
    # $1 会自动接收到出错时的行号 ($LINENO)
    echo -e "${RED}❌ 错误：脚本在第 $1 行执行失败。正在中止...${NC}" >&2
    exit 1
}

# 检查并安装脚本依赖
check_and_install_deps() {
    local missing_deps=()
    local deps=("wget" "jq" "lsb-release" "ca-certificates" "git" "curl")
    echo -e "${CYAN}🔍 正在检查脚本依赖...${NC}"
    for dep in "${deps[@]}"; do
        # 对于 lsb-release 包，其命令是 lsb_release
        local cmd_name="$dep"
        if [ "$dep" == "lsb-release" ]; then
            cmd_name="lsb_release"
        fi

        if ! command -v "$cmd_name" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  检测到以下依赖缺失: ${missing_deps[*]}${NC}"
        echo -e "${CYAN}🔧 正在自动安装依赖...${NC}"
        sudo apt-get update
        sudo apt-get install -y "${missing_deps[@]}"
        echo -e "${GREEN}✅ 依赖安装完成。${NC}"
    else
        echo -e "${GREEN}✅ 所有依赖均已满足。${NC}"
    fi
}

# 检测 IP 地址并设置 GitHub 镜像
set_github_mirror() {
    echo -e "${CYAN}🌍 正在检测网络环境...${NC}"
    # 使用 ipinfo.io 获取国家代码，设置5秒超时，失败则返回空。
    local country_code
    country_code=$(curl -s --connect-timeout 5 https://ipinfo.io/country || echo "")

    # 默认前缀为空
    GITHUB_URL_PREFIX=""

    if [ "$country_code" == "CN" ]; then
        echo -e "${YELLOW}⚠️  检测到您在中国大陆，将使用镜像加速下载...${NC}"
        GITHUB_URL_PREFIX="https://git.99886655.xyz/"
    else
        echo -e "${GREEN}✅ 将使用 GitHub 官方源进行下载。${NC}"
    fi
}


# --- 脚本开始 ---
# 设置陷阱 (trap)，在接收到 ERR 信号 (任何命令失败) 时执行 handle_error 函数
trap 'handle_error $LINENO' ERR

# set -e: 如果任何命令失败，脚本将立即退出 (这会触发上面的 trap)
set -e

# 首先执行依赖检查和镜像设置
check_and_install_deps
set_github_mirror


# --- 主逻辑开始 ---
VERSION_CODENAME=""
# 检测操作系统和版本代号
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" == "debian" ]; then
        VERSION_CODENAME=$(lsb_release -cs)
    fi
fi

# --- Debian 11 (Bullseye) 的特殊处理逻辑：从源代码编译 ---
if [ "$VERSION_CODENAME" == "bullseye" ]; then
    echo -e "${YELLOW}ℹ️  检测到您的系统是 Debian 11 (Bullseye)。${NC}"
    echo -e "${CYAN}为了确保兼容性，将通过编译源代码的方式进行安装...${NC}"

    # 检查并安装编译所需的依赖
    local build_deps=("build-essential" "cmake" "libpci-dev" "libvulkan-dev" "libxcb-randr0-dev" "libxrandr-dev" "libxcb-image0-dev" "libdbus-1-dev")
    local missing_build_deps=()
    echo -e "${CYAN}🔍 正在检查编译依赖...${NC}"
    for dep in "${build_deps[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$dep" 2>/dev/null | grep -q "ok installed"; then
            missing_build_deps+=("$dep")
        fi
    done

    if [ ${#missing_build_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  检测到以下编译依赖缺失: ${missing_build_deps[*]}${NC}"
        echo -e "${CYAN}🔧 正在自动安装...${NC}"
        sudo apt-get update
        sudo apt-get install -y "${missing_build_deps[@]}"
    else
        echo -e "${GREEN}✅ 编译依赖均已满足。${NC}"
    fi
    
    # 在临时目录中进行编译
    tmp_dir=$(mktemp -d)
    echo -e "${CYAN}📥 正在从 GitHub 下载源代码至 ${tmp_dir}...${NC}"
    git clone --depth 1 "${GITHUB_URL_PREFIX}https://github.com/fastfetch-cli/fastfetch.git" "$tmp_dir"
    cd "$tmp_dir"

    echo -e "${CYAN}🛠️  正在编译源代码... (这可能需要一些时间)${NC}"
    mkdir build && cd build
    cmake ..
    make -j"$(nproc)"

    echo -e "${CYAN}📦 正在安装 fastfetch...${NC}"
    sudo make install
    
    echo -e "${CYAN}🧹 正在清理临时文件...${NC}"
    cd ~
    rm -rf "$tmp_dir"

    echo -e "${GREEN}🎉 fastfetch 已通过编译成功安装！${NC}"
    exit 0
fi


# --- 适用于 Debian 12+ 或其他系统的标准逻辑 ---
project_name="LinusDierheimer/fastfetch"

echo -e "${CYAN}🚀 正在为 ${project_name} 寻找最新的发行版...${NC}"

latest_release_info=$(wget -qO- "${GITHUB_URL_PREFIX}https://api.github.com/repos/${project_name}/releases/latest")
latest_version=$(echo "${latest_release_info}" | jq -r '.tag_name')

# 检查 fastfetch 是否已安装
if command -v fastfetch &> /dev/null; then
    current_version=$(fastfetch --version | head -n 1 | awk '{print $2}')
    echo -e "${YELLOW}ℹ️  检测到已安装 fastfetch。${NC}"
    echo -e "${YELLOW}   - 当前版本: ${current_version}${NC}"
    echo -e "${GREEN}   - 最新版本: ${latest_version}${NC}"

    if [ "${current_version}" == "${latest_version}" ]; then
        echo -e "${GREEN}✅ 已经是最新版本，无需任何操作。${NC}"
        exit 0
    fi
else
    echo -e "${YELLOW}ℹ️  系统中未安装 fastfetch。准备进行全新安装...${NC}"
fi


arch=$(uname -m)
deb_arch=""

case "${arch}" in
    "x86_64")  deb_arch="amd64" ;;
    "aarch64") deb_arch="aarch64" ;;
    "armv7l")  deb_arch="armv7l" ;;
    "armv6l")  deb_arch="armv6l" ;;
    *)
        echo "错误：您的系统架构 '${arch}' 不在支持的列表中。"
        exit 1
        ;;
esac

echo -e "${CYAN}⚙️  检测到系统架构: ${arch} (对应包架构: ${deb_arch})${NC}"

release_name=$(echo "${latest_release_info}" | jq -r --arg ARCH "${deb_arch}" '.assets[].name | select(contains($ARCH) and endswith(".deb"))')

if [ -z "${release_name}" ]; then
    echo "错误：无法为您的架构 '${deb_arch}' 找到对应的 .deb 发行包。"
    exit 1
fi

release_url="${GITHUB_URL_PREFIX}https://github.com/${project_name}/releases/download/${latest_version}/${release_name}"

echo -e "${CYAN}⏬ 准备从以下链接下载: ${release_url}${NC}"

wget -c "${release_url}" -q --show-progress

echo -e "${GREEN}✅ 下载完成。准备安装...${NC}"

if [ "$EUID" -ne 0 ]; then
    sudo dpkg -i "${release_name}"
else
    dpkg -i "${release_name}"
fi

rm "${release_name}"

echo -e "${GREEN}🎉 fastfetch 安装/更新完成！${NC}"
