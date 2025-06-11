# 脚本名称: install- system-information.sh
# 功能: 登录终端显示系统信息
#!/bin/bash

# --- 颜色和表情符号定义 ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 当脚本遇到错误时，调用此函数
handle_error() {
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

# 为 Fastfetch 配置自定义文件，并美化输出
configure_fastfetch() {
    local config_url="https://gist.githubusercontent.com/Silentely/a1773867592cf31479bf8d45713b60d2/raw/config.jsonc"
    local config_dir="/root/.config/fastfetch"
    local config_path="${config_dir}/config.jsonc"

    echo -e "${CYAN}🔧 正在为 Fastfetch 配置自定义文件...${NC}"
    sudo mkdir -p "$config_dir"
    sudo wget -O "$config_path" "$config_url"
    echo -e "${GREEN}✅ Fastfetch 配置文件下载完成。${NC}"
    echo -e "${CYAN}-------------------------------${NC}"
    echo -e "${CYAN}如需手动运行，请执行：${NC}\n"
    echo -e "  ${BOLD}${GREEN}fastfetch${NC}\n"
    echo -e "${CYAN}-------------------------------${NC}"
}

# 为 Debian 11 安装 neofetch
install_neofetch_on_bullseye() {
    echo -e "${YELLOW}ℹ️  检测到您的系统是 Debian 11 (Bullseye)。${NC}"
    echo -e "${CYAN}将为您安装 Neofetch 作为替代方案...${NC}"

    sudo apt-get update
    sudo apt-get install -y neofetch

    echo -e "${CYAN}🔧 正在配置 Neofetch 开机启动...${NC}"
    echo -e '#!/bin/sh\nneofetch' | sudo tee /etc/profile.d/neofetch.sh
    sudo chmod +x /etc/profile.d/neofetch.sh

    configure_neofetch

    echo -e "${GREEN}🎉 Neofetch 已安装并配置完成！请重新登录以查看效果。${NC}"
    echo -e "\n${CYAN}💖 感谢使用此脚本！欢迎访问我的 GitHub 查看更多项目: https://github.com/Silentely/Demo${NC}"
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

if [ "$VERSION_CODENAME" == "bullseye" ]; then
    install_neofetch_on_bullseye
fi

project_name="LinusDierheimer/fastfetch"

if apt-cache show fastfetch &>/dev/null; then
    echo -e "${CYAN}🚀 检测到软件源中存在 fastfetch，将通过 apt 安装...${NC}"
    sudo apt-get update
    sudo apt-get install -y fastfetch
    configure_fastfetch
    echo -e '#!/bin/sh\nfastfetch' | sudo tee /etc/profile.d/fastfetch.sh
    sudo chmod +x /etc/profile.d/fastfetch.sh
    echo -e "${GREEN}🎉 fastfetch 已通过官方源成功安装！${NC}"
    echo -e "\n${CYAN}💖 感谢使用此脚本！欢迎访问我的 GitHub 查看更多项目: https://github.com/Silentely/Demo${NC}"
    exit 0
fi

echo -e "${CYAN}🚀 软件源中未找到 fastfetch，将从 GitHub 下载最新版本...${NC}"
latest_release_info=$(wget -qO- "https://api.github.com/repos/${project_name}/releases/latest")
latest_version=$(echo "${latest_release_info}" | jq -r '.tag_name')

if command -v fastfetch &> /dev/null;
