#!/bin/bash

# 定义颜色变量
Green="\033[32m"  && Red="\033[31m" && GreenBG="\033[42;37m" 
RedBG="\033[41;37m" && Font="\033[0m"

# 函数：显示菜单
show_menu() {
    clear
    echo -e "${GreenBG} Linux SSH 安全配置向导 ${Font}"
    echo -e "1. 仅启用root密码登录"
    echo -e "2. 仅启用密钥登录"
    echo -e "3. 同时启用密码和密钥登录"
    echo -e "0. 退出脚本"
    echo "--------------------------------"
}

# 函数：处理密钥配置
setup_key() {
    echo -ne "${Green}>> 是否已有SSH公钥？(y/n) ${Font}"
    read -r has_key
    
    if [ "$has_key" = "y" ]; then
        echo -e "${Green}>> 请粘贴您的公钥内容（支持RSA/Ed25519，按Ctrl+D结束输入）：${Font}"
        temp_key=$(mktemp)
        while IFS= read -r line; do
            echo "$line" >> "$temp_key"
        done
        # 验证公钥格式
        if ! ssh-keygen -lf "$temp_key" &>/dev/null; then
            echo -e "${RedBG} 错误：无效的公钥格式 ${Font}"
            rm -f "$temp_key"
            exit 1
        fi
        cat "$temp_key" >> /root/.ssh/authorized_keys
        rm -f "$temp_key"
        echo -e "${GreenBG} 公钥已成功添加 ${Font}"
    else
        echo -ne "${Green}>> 选择密钥类型 (1) Ed25519（推荐） (2) RSA-4096：${Font}"
        read -r key_type
        case $key_type in
            1)
                key_type="ed25519"
                key_opts="-t ed25519"
                ;;
            2|*)
                key_type="rsa"
                key_opts="-t rsa -b 4096"
                ;;
        esac
        
        echo -e "${Green}>> 正在生成${key_type^^}密钥对... ${Font}"
        mkdir -p /root/.ssh
        ssh-keygen $key_opts -N "" -f /root/.ssh/linux_$key_type
        chmod 600 /root/.ssh/linux_$key_type*
        echo -e "${RedBG} 重要！请立即下载私钥文件：/root/.ssh/linux_$key_type ${Font}"
    fi
}

# 函数：应用配置
apply_config() {
    # 备份原始配置文件
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak_$(date +%s)
    
    sed -i "s/^#*PermitRootLogin.*/PermitRootLogin $1/" /etc/ssh/sshd_config
    sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication $2/" /etc/ssh/sshd_config
    sed -i "s/^#*PubkeyAuthentication.*/PubkeyAuthentication $3/" /etc/ssh/sshd_config
    systemctl restart ssh
}

# 主程序
main() {
    # 确保root目录存在
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    while true; do
        show_menu
        echo -ne "${Green}>> 请选择操作编号：${Font}"
        read -r choice
        
        case $choice in
            1)  # 仅密码登录
                apply_config yes yes no
                echo -e "${GreenBG} 已启用密码登录，请立即使用passwd命令设置root密码！ ${Font}"
                break
                ;;
            2)  # 仅密钥登录
                setup_key
                apply_config prohibit-password no yes
                echo -e "${GreenBG} 密钥登录已启用，密码登录已禁用 ${Font}"
                break
                ;;
            3)  # 同时启用
                setup_key
                apply_config yes yes yes
                echo -e "${GreenBG} 密码和密钥登录均已启用，请设置root密码：${Font}"
                passwd
                break
                ;;
            0)
                echo "退出脚本"
                exit 0
                ;;
            *)
                echo -e "${RedBG} 无效选择，请重新输入 ${Font}"
                sleep 2
                ;;
        esac
    done

    # 显示最终连接信息
    echo -e "\n${Green}========================================"
    echo -e "服务器IP：$(curl -s icanhazip.com)"
    echo -e "密钥路径：/root/.ssh/$(ls /root/.ssh | grep linux_ | grep -v .pub)"
    echo -e "支持协议：Ed25519/RSA"
    echo -e "连接示例：ssh -i 密钥路径 root@你的服务器IP"
    echo -e "========================================${Font}"
    
    # 安全提醒
    echo -e "\n${RedBG}[安全提示]${Font}"
    echo -e "1. 请及时测试新登录方式是否生效"
    echo -e "2. 建议在物理安全的环境操作"
    echo -e "3. 密钥文件请设置400权限：chmod 400 密钥文件"
}

# 执行主程序
main
