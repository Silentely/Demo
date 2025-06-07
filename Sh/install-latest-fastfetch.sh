#!/bin/bash
# 脚本名称: install-latest-fastfetch.sh
# 功能: 从 GitHub 下载并安装最新版的 fastfetch (.deb 包)

set -e
project_name="LinusDierheimer/fastfetch"

echo "正在为 ${project_name} 寻找最新版本..."

latest_release_info=$(wget -qO- "https://api.github.com/repos/${project_name}/releases/latest")

tag_name=$(echo "${latest_release_info}" | jq -r '.tag_name')
release_name=$(echo "${latest_release_info}" | jq -r '.assets[].name' | grep '\.deb$')

if [ -z "${release_name}" ]; then
    echo "错误：无法在此项目的最新版本中找到 .deb 发行包。"
    exit 1
fi

release_url="https://github.com/${project_name}/releases/download/${tag_name}/${release_name}"

echo "找到版本: ${tag_name}"
echo "正在从以下链接下载: ${release_url}"

wget -c "${release_url}" -q --show-progress

echo "下载完成。准备安装..."

if [ "$EUID" -ne 0 ]; then
    echo "需要管理员权限，使用 sudo 进行安装..."
    sudo dpkg -i "${release_name}"
else
    echo "以 root 权限直接安装..."
    dpkg -i "${release_name}"
fi

echo "清理安装包..."
rm "${release_name}"

echo "fastfetch 安装完成！ 🎉"
