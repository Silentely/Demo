#!/bin/bash

# 定义颜色变量
Green="\033[32m"
Red="\033[31m"
GreenBG="\033[42;37m" 
RedBG="\033[41;37m"
Font="\033[0m"

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RedBG} 错误：请以root权限运行此脚本 ${Font}"
        exit 1
    fi
}

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
        cat > "$temp_key"
        
        # 验证公钥格式
        if ! ssh-keygen -lf "$temp_key" &>/dev/null; then
            echo -e "${RedBG} 错误：无效的公钥格式 ${Font}"
            rm -f "$temp_key"
            exit 1
        fi
        
        # 确保目录和文件权限正确
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        touch /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        
        cat "$temp_key" >> /root/.ssh/authorized_keys
        rm -f "$temp_key"
        echo -e "${GreenBG} 公钥已成功添加 ${Font}"
    else
        echo -ne "${Green}>> 选择密钥类型 (1) Ed25519（推荐） (2) RSA-4096：${Font}"
        read -r key_type_choice
        case $key_type_choice in
            1)
                key_type="ed25519"
                key_opts="-t ed25519"
                ;;
            2|*)
                key_type="rsa"
                key_opts="-t rsa -b 4096"
                ;;
        esac
        
        key_type_display=$(echo "$key_type" | tr '[:lower:]' '[:upper:]')
        echo -e "${Green}>> 正在生成${key_type_display}密钥对... ${Font}"
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        
        if ! ssh-keygen $key_opts -N "" -f "/root/.ssh/linux_$key_type"; then
            echo -e "${RedBG} 错误：密钥生成失败 ${Font}"
            exit 1
        fi
        
        chmod 600 /root/.ssh/linux_$key_type*
        cat "/root/.ssh/linux_$key_type.pub" >> /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
        
        echo -e "${RedBG} 重要！请立即下载私钥文件：/root/.ssh/linux_$key_type ${Font}"
    fi
}

# 函数：应用配置
apply_config() {
    # 创建带时间戳的备份
    backup_file="/etc/ssh/sshd_config.bak_$(date +%s)"
    cp /etc/ssh/sshd_config "$backup_file"
    echo -e "${Green}>> 配置已备份至：${backup_file}${Font}"
    
    # 应用新配置
    sed -i "s/^#*PermitRootLogin.*/PermitRootLogin $1/" /etc/ssh/sshd_config
    sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication $2/" /etc/ssh/sshd_config
    sed -i "s/^#*PubkeyAuthentication.*/PubkeyAuthentication $3/" /etc/ssh/sshd_config
    
    # 确保关键选项存在，如果不存在则添加
    grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin $1" >> /etc/ssh/sshd_config
    grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication $2" >> /etc/ssh/sshd_config
    grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication $3" >> /etc/ssh/sshd_config
}

# 函数：安全重启SSH
restart_ssh() {
    # 配置文件语法检查
    if ! sshd -t; then
        echo -e "${RedBG} 错误：SSH配置存在语法错误，请检查以下问题：${Font}"
        sshd -t
        echo -e "\n${Green}>> 可以从备份恢复配置：${Font}"
        ls -lh /etc/ssh/sshd_config.bak_*
        exit 1
    fi

    # 获取服务名称（适配不同发行版）
    service_name=$(systemctl list-units --type=service | grep -E 'ssh(d)?\.service' | awk '{print $1}' | head -n 1)
    
    if [ -z "$service_name" ]; then
        echo -e "${RedBG} 错误：无法确定SSH服务名称 ${Font}"
        echo -e "请手动重启SSH服务"
        exit 1
    fi

    echo -ne "\n${Green}>> 是否立即重启SSH服务？(y/n) ${Font}"
    read -r restart_choice
    if [ "$restart_choice" = "y" ]; then
        echo -e "${Green}正在重启SSH服务...${Font}"
        systemctl restart "$service_name"
        
        # 检查服务状态
        sleep 2
        if systemctl is-active --quiet "$service_name"; then
            echo -e "${GreenBG} SSH服务重启成功 ${Font}"
        else
            echo -e "${RedBG} 错误：SSH服务启动失败，请检查日志：journalctl -u $service_name ${Font}"
            echo -e "\n${Green}>> 可以从备份恢复配置：${Font}"
            ls -lh /etc/ssh/sshd_config.bak_*
            exit 1
        fi
    else
        echo -e "${RedBG} 警告：配置更改尚未生效！${Font}"
        echo -e "请手动执行以下命令生效：\nsystemctl restart $service_name"
    fi
}

# 函数：获取服务器IP地址
get_ip_address() {
    # 多种方式尝试获取IP地址
    ip=$(curl -s -m 10 icanhazip.com || curl -s -m 10 ipinfo.io/ip || curl -s -m 10 ifconfig.me)
    
    if [ -z "$ip" ]; then
        # 如果在线服务都失败，尝试从本地网络接口获取
        ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | head -n 1)
    fi
    
    if [ -z "$ip" ]; then
        echo "无法获取IP地址"
    else
        echo "$ip"
    fi
}

# 主程序
main() {
    # 检查root权限
    check_root
    
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
                passwd root
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
                passwd root
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

    # 安全重启服务
    restart_ssh

    # 显示连接信息
    server_ip=$(get_ip_address)
    echo -e "\n${Green}========================================"
    echo -e "服务器IP：$server_ip"
    [ -f /root/.ssh/linux_ed25519 ] && echo -e "Ed25519密钥：/root/.ssh/linux_ed25519"
    [ -f /root/.ssh/linux_rsa ] && echo -e "RSA-4096密钥：/root/.ssh/linux_rsa"
    echo -e "连接命令：ssh -i [密钥路径] root@$server_ip"
    echo -e "========================================${Font}"

    # 最终安全提示
    echo -e "\n${RedBG}[!] 重要安全提醒 ${Font}"
    echo -e "1. 请在新窗口测试连接，确认正常后再关闭当前会话！"
    echo -e "2. 备份配置文件列表："
    ls -lh /etc/ssh/sshd_config.bak_*
}

# 执行主程序
main
