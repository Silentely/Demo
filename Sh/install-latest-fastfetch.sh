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
    local country_code
    country_code=$(curl -s --connect-timeout 5 https://ipinfo.io/country || echo "")

    GITHUB_URL_PREFIX=""
    if [ "$country_code" == "CN" ]; then
        echo -e "${YELLOW}⚠️  检测到您在中国大陆，将使用镜像加速下载...${NC}"
        GITHUB_URL_PREFIX="https://git.99886655.xyz/"
    else
        echo -e "${GREEN}✅ 将使用 GitHub 官方源进行下载。${NC}"
    fi
}

# 为 Neofetch 配置自定义文件
configure_neofetch() {
    local config_url="https://gist.githubusercontent.com/Silentely/a1773867592cf31479bf8d45713b60d2/raw/config.conf"
    local config_dir="/root/.config/neofetch"
    local config_path="${config_dir}/config.conf"

    echo -e "${CYAN}📥 正在下载 Neofetch 配置文件...${NC}"
    sudo mkdir -p "$config_dir"
    sudo wget -O "$config_path" "$config_url"
}

# 为 Fastfetch 配置自定义文件
configure_fastfetch() {
    local config_url="https://gist.githubusercontent.com/Silentely/a1773867592cf31479bf8d45713b60d2/raw/config.jsonc"
    local config_dir="/root/.config/fastfetch"
    local config_path="${config_dir}/config.jsonc"

    echo -e "${CYAN}🔧 正在为 Fastfetch 配置自定义文件...${NC}"
    sudo mkdir -p "$config_dir"
    sudo wget -O "$config_path" "$config_url"
    echo -e "${GREEN}✅ Fastfetch 配置文件下载完成。${NC}"
}

# 为 Debian 11 安装 neofetch
install_neofetch_on_bullseye() {
    echo -e "${YELLOW}ℹ️  检测到您的系统是 Debian 11 (Bullseye)。${NC}"
    echo -e "${CYAN}将为您安装 Neofetch 作为替代方案...${NC}"

    # 安装 neofetch
    sudo apt-get update
    sudo apt-get install -y neofetch

    # 创建 profile.d 脚本，使其在登录时自动运行
    echo -e "${CYAN}🔧 正在配置 Neofetch 开机启动...${NC}"
    echo -e '#!/bin/sh\nneofetch' | sudo tee /etc/profile.d/neofetch.sh
    sudo chmod +x /etc/profile.d/neofetch.sh

    # 下载并应用配置文件
    configure_neofetch

    echo -e "${GREEN}🎉 Neofetch 已安装并配置完成！请重新登录以查看效果。${NC}"
    exit 0
}


# --- 脚本开始 ---
trap 'handle_error $LINENO' ERR
set -e

check_and_install_deps
set_github_mirror


# --- 主逻辑开始 ---
VERSION_CODENAME=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" == "debian" ]; then
        VERSION_CODENAME=$(lsb_release -cs)
    fi
fi

# 如果是 Debian 11，执行 neofetch 安装流程
if [ "$VERSION_CODENAME" == "bullseye" ]; then
    install_neofetch_on_bullseye
fi


# --- 适用于 Debian 12+ 或其他系统的标准逻辑 ---
project_name="LinusDierheimer/fastfetch"

# 尝试从 apt 安装
if apt-cache show fastfetch &>/dev/null; then
    echo -e "${CYAN}🚀 检测到软件源中存在 fastfetch，将通过 apt 安装...${NC}"
    sudo apt-get update
    sudo apt-get install -y fastfetch
    configure_fastfetch
    echo -e "${GREEN}🎉 fastfetch 已通过官方源成功安装！${NC}"
    exit 0
fi

# 如果 apt 中没有，则从 GitHub 下载
echo -e "${CYAN}🚀 软件源中未找到 fastfetch，将从 GitHub 下载最新版本...${NC}"
latest_release_info=$(wget -qO- "https://api.github.com/repos/${project_name}/releases/latest")
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
configure_fastfetch
echo -e "${GREEN}🎉 fastfetch 安装/更新完成！${NC}"
