#!/usr/bin/env bash
#
# 青龙一键安装依赖脚本
# GitHub仓库： https://github.com/FlechazoPh/QLDependency
# 修复映射data目录 @Silentely
#

TIME() {
[[ -z "$1" ]] && {
	echo -ne " "
} || {
     case $1 in
	r) export Color="\e[31;1m";;
	g) export Color="\e[32;1m";;
	b) export Color="\e[34;1m";;
	y) export Color="\e[33;1m";;
	z) export Color="\e[35;1m";;
	l) export Color="\e[36;1m";;
      esac
	[[ $# -lt 2 ]] && echo -e "\e[36m\e[0m ${1}" || {
		echo -e "\e[36m\e[0m ${Color}${2}\e[0m"
	 }
      }
}

echo
echo
echo
TIME l "安装依赖..."
echo
TIME y "安装依赖需要时间，请耐心等待!"
echo
sleep 3
echo
echo

echo "当前node版本(如果没有node，请自行安装): "
node -v || true

echo "当前npm版本(如果没有npm，请自行安装): "
npm -v || true

npm config set registry https://registry.npmmirror.com 2>/dev/null || true
cd /ql/ 2>/dev/null || true
pnpm add -g pnpm 2>/dev/null || npm install -g pnpm 2>/dev/null || true

pnpm install -g 2>/dev/null || true

npm install -g npm png-js date-fns axios crypto-js ts-md5 tslib @types/node requests tough-cookie jsdom download tunnel fs ws form-data 2>/dev/null || true

pnpm install -g js-base64 qrcode-terminal silly-datetime 2>/dev/null || true

# 适配 PEP 668 (Python 3.12+ / Alpine 3.19+)
pip3 install --break-system-packages requests 2>/dev/null || pip3 install requests 2>/dev/null || true

if [ -d "/ql/data/scripts" ]; then
    cd /ql/data/scripts/ && apk add --no-cache build-base g++ cairo-dev pango-dev giflib-dev 2>/dev/null || true
    npm i 2>/dev/null || true
    npm i -S ts-node typescript @types/node date-fns axios png-js canvas --build-from-source 2>/dev/null || true
fi

if [ -d "/ql" ]; then
    cd /ql/ && apk add --no-cache build-base g++ cairo-dev pango-dev giflib-dev 2>/dev/null || true
    cd /ql/data/scripts/ 2>/dev/null && npm install canvas --build-from-source 2>/dev/null || true
    cd /ql/ && apk add --no-cache python3 zlib-dev gcc jpeg-dev python3-dev musl-dev freetype-dev 2>/dev/null || true
fi

echo
TIME g "依赖安装完毕...建议重启 Docker "
echo
TIME g "有任何问题，请在此仓库提交Issue： https://github.com/FlechazoPh/QLDependency"
echo
exit 0
