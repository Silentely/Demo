#!/bin/bash
# 脚本名称: install-latest-fastfetch.sh
# 功能: 从 GitHub 下载并安装最新版的 fastfetch (.deb 包)
#!/bin/bash

# 当脚本遇到错误时，调用此函数
handle_error() {
    # $1 会自动接收到出错时的行号 ($LINENO)
    echo "错误：脚本在第 $1 行执行失败。正在中止..." >&2
    exit 1
}

# 设置陷阱 (trap)，在接收到 ERR 信号 (任何命令失败) 时执行 handle_error 函数
trap 'handle_error $LINENO' ERR

# set -e: 如果任何命令失败，脚本将立即退出 (这会触发上面的 trap)
set -e

project_name="LinusDierheimer/fastfetch"

echo "正在为 ${project_name} 寻找最新的发行版..."

latest_release_info=$(wget -qO- "https://api.github.com/repos/${project_name}/releases/latest")
tag_name=$(echo "${latest_release_info}" | jq -r '.tag_name')
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

echo "检测到系统架构: ${arch} (对应包架构: ${deb_arch})"

release_name=$(echo "${latest_release_info}" | jq -r --arg ARCH "${deb_arch}" '.assets[].name | select(contains($ARCH) and endswith(".deb"))')

if [ -z "${release_name}" ]; then
    echo "错误：无法为您的架构 '${deb_arch}' 找到对应的 .deb 发行包。"
    exit 1
fi

release_url="https://github.com/${project_name}/releases/download/${tag_name}/${release_name}"

echo "成功找到版本: ${tag_name}"
echo "准备从以下链接下载: ${release_url}"

wget -c "${release_url}" -q --show-progress

echo "下载完成。准备安装..."

if [ "$EUID" -ne 0 ]; then
    sudo dpkg -i "${release_name}"
else
    dpkg -i "${release_name}"
fi

rm "${release_name}"

echo "fastfetch 安装完成！ 🎉"
