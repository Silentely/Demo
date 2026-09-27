#!/usr/bin/env bash

Folder="/usr/local/gost"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_sys(){
	if [[ -f /etc/redhat-release ]]; then
		command -v python3 &>/dev/null || yum install python3 -y
		release="centos"
	elif grep -q -E -i "debian" /etc/issue 2>/dev/null || grep -q -E -i "debian" /proc/version 2>/dev/null; then
		command -v python3 &>/dev/null || apt-get install python3 -y
		release="debian"
	elif grep -q -E -i "ubuntu" /etc/issue 2>/dev/null || grep -q -E -i "ubuntu" /proc/version 2>/dev/null; then
		command -v python3 &>/dev/null || apt-get install python3 -y
		release="ubuntu"
	else
		command -v python3 &>/dev/null || (apt-get install python3 -y 2>/dev/null || yum install python3 -y 2>/dev/null)
		release="linux"
	fi
	bit=`uname -m`
}

check_pid(){
	PID=`pgrep -f "gost -C" || true`
	[[ -z "$PID" ]] && PID=`ps -ef | grep "/usr/bin/gost" | grep -v "grep" | grep -v "gost.sh" | awk '{print $2}'`
}

get_ip(){
	ip=$(curl -s --connect-timeout 2 https://api.ipify.org || curl -s --connect-timeout 2 https://ifconfig.me || wget -qO- -t1 -T2 ipinfo.io/ip || echo "VPS_IP")
}

check_new_ver(){
	echo -e "${Info} 正在获取 Gost 最新版本..."
	if [[ -z ${gost_new_ver} ]]; then
		gost_new_ver=$(curl -sL https://api.github.com/repos/ginuerzh/gost/releases 2>/dev/null | grep -o '"tag_name": ".*"' | head -n 1 | sed 's/"//g;s/v//g;s/tag_name: //g')
		if [[ -z ${gost_new_ver} ]]; then
			gost_new_ver="2.11.5" # 稳定兜底版本
			echo -e "${Tip} 获取最新版本失败，使用默认稳定版本 [ ${gost_new_ver} ]"
		else
			echo -e "${Info} 检测到 gost 最新版本为 [ ${gost_new_ver} ]"
		fi
	else
		echo -e "${Info} 即将下载 gost 版本： [ ${gost_new_ver} ]"
	fi
}

check_install_status(){
	[[ ! -e "/usr/bin/gost" ]] && echo -e "${Error} gost 没有安装，请检查 !" && exit 1
	[[ ! -e "/root/.gost/config.json" ]] && echo -e "${Error} gost 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
}

download_gost(){
	if [[ ${bit} == "x86_64" ]]; then
		bit="amd64"
	elif [[ ${bit} == "i386" || ${bit} == "i686" ]]; then
		bit="386"
	elif [[ ${bit} == "aarch64" || ${bit} == "arm64" ]]; then
		bit="arm64"
	else
		bit="armv7"
	fi

	local download_url="https://github.com/ginuerzh/gost/releases/download/v${gost_new_ver}/gost-linux-${bit}-${gost_new_ver}.gz"
	echo -e "${Info} 正在下载: ${download_url}"
	curl -fsSL --connect-timeout 10 -o "gost-linux-${bit}-${gost_new_ver}.gz" "${download_url}" || wget -N "${download_url}"
	gost_name="gost-linux-${bit}-${gost_new_ver}"

	[[ ! -s "${gost_name}.gz" ]] && echo -e "${Error} gost 压缩包下载失败 !" && exit 1
	gzip -d -f "${gost_name}.gz"
	[[ ! -e "${gost_name}" ]] && echo -e "${Error} gost 解压失败 !" && exit 1
	mkdir -p "${Folder}" && mv -f "${gost_name}" "${Folder}/gost"
	chmod +x "${Folder}/gost"
	cp -f "${Folder}/gost" /usr/bin/gost

	mkdir -p /root/.gost
	if [[ ! -f /root/.gost/config.json ]]; then
		cat << 'EOF' > /root/.gost/config.json
{
    "Debug": true,
    "Retries": 3,
    "ServeNodes": []
}
EOF
	fi
	echo -e "${Info} gost 主程序安装完毕！开始配置服务文件..."
}

service_gost(){
	if command -v systemctl >/dev/null 2>&1; then
		cat << 'EOF' > /etc/systemd/system/gost.service
[Unit]
Description=GO Simple Tunnel Service
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/gost -C /root/.gost/config.json
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
		systemctl daemon-reload
		systemctl enable gost
		echo -e "${Info} gost systemd 服务安装完毕！"
	else
		cat << 'EOF' > /etc/init.d/gost
#!/bin/bash
# chkconfig: 2345 90 10
# description: GO Simple Tunnel Service

NAME=gost
BIN=/usr/bin/gost
CONF=/root/.gost/config.json

start() {
    $BIN -C $CONF >/dev/null 2>&1 &
    echo "gost started"
}

stop() {
    pkill -f "$BIN -C $CONF" 2>/dev/null
    echo "gost stopped"
}

case "$1" in
    start) start ;;
    stop) stop ;;
    restart) stop; sleep 1; start ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
exit 0
EOF
		chmod +x /etc/init.d/gost
		echo -e "${Info} gost SysVinit 脚本安装完毕！"
	fi
}

config_gost_l(){
	echo -e "请选择你要进行的操作 \n\n${Green_font_prefix}1.${Font_color_suffix} 清除并重新设置 -L参数\n${Green_font_prefix}2.${Font_color_suffix} 增加 -L参数" && echo
	read -e -p "(默认：取消) " l_code
	[[ -z "${l_code}" ]] && l_code="0"
	if [[ ${l_code} == "1" ]]; then
		python3 -c '
import json
cfg_file = "/root/.gost/config.json"
try:
    with open(cfg_file, "r") as f:
        data = json.load(f)
    data["ServeNodes"] = []
    with open(cfg_file, "w") as f:
        json.dump(data, f, indent=4)
except Exception:
    pass
'
		config_gost_l_add
	elif [[ ${l_code} == "2" ]]; then
		config_gost_l_add
	else
		exit 1
	fi
	echo -e "${Info} -L参数 设置完毕"
}

config_gost_f(){
	echo -e "请选择你要进行的操作 \n\n${Green_font_prefix}1.${Font_color_suffix} 清除并重新设置 -F参数\n${Green_font_prefix}2.${Font_color_suffix} 增加 -F参数\n${Green_font_prefix}3.${Font_color_suffix} 不使用 -F参数" && echo
	read -e -p "(默认：取消) " f_code
	[[ -z "${f_code}" ]] && f_code="0"
	if [[ ${f_code} == "1" ]]; then
		python3 -c '
import json
cfg_file = "/root/.gost/config.json"
try:
    with open(cfg_file, "r") as f:
        data = json.load(f)
    if "ChainNodes" in data:
        del data["ChainNodes"]
    with open(cfg_file, "w") as f:
        json.dump(data, f, indent=4)
except Exception:
    pass
'
		config_gost_f_add
	elif [[ ${f_code} == "2" ]]; then
		config_gost_f_add
	elif [[ ${f_code} == "3" ]]; then
		python3 -c '
import json
cfg_file = "/root/.gost/config.json"
try:
    with open(cfg_file, "r") as f:
        data = json.load(f)
    if "ChainNodes" in data:
        del data["ChainNodes"]
    with open(cfg_file, "w") as f:
        json.dump(data, f, indent=4)
except Exception:
    pass
' 2>/dev/null || true
	else
		exit 1
	fi
}

config_gost_l_add(){
	echo -e "请输入 -L 参数"
	read -e -p "(默认 - [:6666] (Http+Socks5二合一)例如\":XXXX\",如需设置密码则输入“admin:123456@:6666”,如需单独设置Socks5则输入“socks5://:XXXX”,带密码则输入“socks5://admin:123456@:6666”): " param_l
	[[ -z "$param_l" ]] && param_l=":6666"
	GOST_PARAM_L="$param_l" python3 -c '
import os, json
param = os.environ.get("GOST_PARAM_L", "")
cfg_file = "/root/.gost/config.json"
try:
    with open(cfg_file, "r") as f:
        data = json.load(f)
except Exception:
    data = {"Debug": True, "Retries": 3}
data.setdefault("ServeNodes", []).append(param)
with open(cfg_file, "w") as f:
    json.dump(data, f, indent=4)
print(data["ServeNodes"])
' && echo -e "${Info} 配置更新成功"
	echo -e "是否继续添加 -L 参数 (0:取消/1:继续)"
	read -e -p "(默认：取消) " l_add_code
	[[ -z "${l_add_code}" ]] && l_add_code="0"
	if [[ ${l_add_code} == "1" ]]; then
		config_gost_l_add
	fi
}

config_gost_f_add(){
	echo -e "请输入 -F 参数"
	read -e -p "(默认 - [http://192.168.1.1:8080] 例如\"http://XX.XX.XX.XX:XXXX\",如需设置密码则输入“http://admin:123456@192.168.1.1:8080”,如需设置Socks5则输入“socks5://:XXXX”,带密码则输入“socks5://admin:123456@192.168.1.1:8080”): " param_f
	[[ -z "$param_f" ]] && param_f="http://192.168.1.1:8080"
	GOST_PARAM_F="$param_f" python3 -c '
import os, json
param = os.environ.get("GOST_PARAM_F", "")
cfg_file = "/root/.gost/config.json"
try:
    with open(cfg_file, "r") as f:
        data = json.load(f)
except Exception:
    data = {"Debug": True, "Retries": 3}
data.setdefault("ChainNodes", []).append(param)
with open(cfg_file, "w") as f:
    json.dump(data, f, indent=4)
print(data["ChainNodes"])
' && echo -e "${Info} 配置更新成功"
	echo -e "是否继续添加 -F 参数 (0:取消/1:继续)"
	read -e -p "(默认：取消) " f_add_code
	[[ -z "${f_add_code}" ]] && f_add_code="0"
	if [[ ${f_add_code} == "1" ]]; then
		config_gost_f_add
	fi
}

View_config(){
	echo -e "${Info} -L参数为:"
	python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));print (j.get('ServeNodes', []))" 2>/dev/null || true
	if grep -q "ChainNodes" /root/.gost/config.json 2>/dev/null; then
		echo -e "${Info} -F参数为:"
		python3 -c "import json;j = (json.load(open(\"/root/.gost/config.json\",'r')));print (j.get('ChainNodes', []))" 2>/dev/null || true
	fi
}

Set_config(){
	echo && echo -e "gost 配置菜单\n————————————————————————\n${Green_font_prefix}1.${Font_color_suffix} 设置-L参数(Http加Socks5代理)\n${Green_font_prefix}2.${Font_color_suffix} 设置-F参数(转发代理)" && echo
	read -e -p "(默认：取消) " config_code
	[[ -z "${config_code}" ]] && config_code="0"
	if [[ ${config_code} == "1" ]]; then
		config_gost_l
		Restart_gost
	elif [[ ${config_code} == "2" ]]; then
		config_gost_f
		Restart_gost
	else
		exit 1
	fi
}

Install_gost(){
	check_sys
	check_new_ver
	download_gost
	service_gost
	echo -e "${Info} gost 已安装完成！请重新运行脚本进行配置~"
}

Uninstall_gost(){
	check_install_status "un"
	echo -e "确定要卸载 gost ？(y/N)"
	read -e -p "(默认: n): " unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		pkill -f "gost" 2>/dev/null || true
		systemctl stop gost 2>/dev/null || true
		systemctl disable gost 2>/dev/null || true
		rm -f /etc/systemd/system/gost.service 2>/dev/null || true
		systemctl daemon-reload 2>/dev/null || true
		rm -rf "${Folder}"
		rm -f /usr/bin/gost
		rm -rf /root/.gost
		echo -e "${Info} gost 卸载完成 !"
	else
		echo && echo "卸载已取消..." && echo
	fi
}

Start_gost(){
	check_install_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Tip} gost 正在运行，无需再次启动！" && exit 1
	if command -v systemctl >/dev/null 2>&1; then
		systemctl start gost
	else
		/etc/init.d/gost start
	fi
	sleep 1
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Info} gost 启动成功！"
}

Stop_gost(){
	check_install_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Tip} gost 没有运行，无需停止！" && exit 1
	if command -v systemctl >/dev/null 2>&1; then
		systemctl stop gost
	else
		/etc/init.d/gost stop
	fi
	echo -e "${Info} gost 停止成功！"
}

Restart_gost(){
	check_install_status
	if command -v systemctl >/dev/null 2>&1; then
		systemctl restart gost
	else
		/etc/init.d/gost restart
	fi
	sleep 1
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Info} gost 重启成功！"
}

Update_gost(){
	check_install_status
	check_sys
	check_new_ver
	pkill -f "gost" 2>/dev/null || true
	download_gost
	Restart_gost
	echo -e "${Info} gost 更新成功！"
}

show_status(){
	check_pid
	if [[ -n "${PID}" ]]; then
		echo -e "当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}正在运行${Font_color_suffix} (PID: ${PID})"
	elif [[ -e "/usr/bin/gost" ]]; then
		echo -e "当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未运行${Font_color_suffix}"
	else
		echo -e "当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
	fi
}

echo && echo -e "  gost 一键管理脚本
——————————————
  1. 安装 gost
  2. 更新 gost
  3. 卸载 gost
——————————————
  4. 启动 gost
  5. 停止 gost
  6. 重启 gost
——————————————
  7. 配置 gost
  8. 查看 gost 配置
——————————————" && echo
show_status && echo
read -e -p " 请输入数字 [1-8]: " num
case "$num" in
	1)
		Install_gost
		;;
	2)
		Update_gost
		;;
	3)
		Uninstall_gost
		;;
	4)
		Start_gost
		;;
	5)
		Stop_gost
		;;
	6)
		Restart_gost
		;;
	7)
		Set_config
		;;
	8)
		View_config
		;;
	*)
		echo -e "${Error} 请输入正确的数字 [1-8]"
		exit 1
		;;
esac
