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
        echo -e "${RedBG} 错误：请以root用户运行此脚本 ${Font}"
        exit 1
    fi
}

# 函数：安全重启SSH服务
restart_ssh_service() {
    # 配置文件语法检查
    if ! sshd -t; then
        echo -e "${RedBG} 错误：SSH配置文件存在语法错误，请手动修复！ ${Font}"
        exit 1
    fi

    # 获取SSH服务名称（适配不同发行版）
    service_name=$(systemctl list-units --type=service | grep -E 'ssh(d)?\.service' | awk '{print $1}' | head -n 1)
    
    # 检查是否找到SSH服务
    if [ -z "$service_name" ]; then
        echo -e "${RedBG} 错误：无法确定SSH服务名称，请手动重启SSH服务 ${Font}"
        exit 1
    fi

    echo -ne "${Green}>> 是否立即重启SSH服务？(y/n) ${Font}"
    read -r restart_choice
    if [ "$restart_choice" = "y" ]; then
        echo -e "${Green}正在重启SSH服务...${Font}"
        if systemctl restart "$service_name"; then
            echo -e "${GreenBG} SSH服务已成功重启 ${Font}"
        else
            echo -e "${RedBG} SSH服务重启失败，请检查系统日志 ${Font}"
            exit 1
        fi
    else
        echo -e "${RedBG} 警告：配置更改尚未生效，请手动执行以下命令重启：${Font}"
        echo -e "systemctl restart $service_name"
    fi
}

# 验证参数
validate_yes_no() {
    if [ "$1" != "yes" ] && [ "$1" != "no" ]; then
        echo -e "${RedBG} 错误：参数必须为 'yes' 或 'no'，收到：'$1' ${Font}"
        exit 1
    fi
}

# 应用SSH配置
apply_config() {
    # 验证参数
    validate_yes_no "$1"
    validate_yes_no "$2"
    validate_yes_no "$3"
    
    # 创建备份目录
    backup_dir="/etc/ssh/backups"
    mkdir -p "$backup_dir"
    
    # 保留最多10个备份文件
    backup_count=$(ls -1 "$backup_dir" | wc -l)
    if [ "$backup_count" -gt 10 ]; then
        oldest_backup=$(ls -t "$backup_dir" | tail -1)
        rm "$backup_dir/$oldest_backup"
    fi
    
    # 备份原始配置文件（带时间戳）
    backup_file="$backup_dir/sshd_config.bak_$(date +%Y%m%d_%H%M%S)"
    cp /etc/ssh/sshd_config "$backup_file"
    echo -e "${Green}SSH配置已备份至：$backup_file ${Font}"
    
    # 应用新配置
    echo -e "${Green}正在应用新的SSH配置...${Font}"
    sed -i "/^#*PermitRootLogin/s/^#*.*$/PermitRootLogin $1/" /etc/ssh/sshd_config
    sed -i "/^#*PasswordAuthentication/s/^#*.*$/PasswordAuthentication $2/" /etc/ssh/sshd_config
    sed -i "/^#*PubkeyAuthentication/s/^#*.*$/PubkeyAuthentication $3/" /etc/ssh/sshd_config
    
    # 检查是否需要添加不存在的配置项
    grep -q "^PermitRootLogin" /etc/ssh/sshd_config || echo "PermitRootLogin $1" >> /etc/ssh/sshd_config
    grep -q "^PasswordAuthentication" /etc/ssh/sshd_config || echo "PasswordAuthentication $2" >> /etc/ssh/sshd_config
    grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config || echo "PubkeyAuthentication $3" >> /etc/ssh/sshd_config
}

# 主程序
main() {
    check_root
    
    echo -e "${GreenBG} SSH安全配置工具 ${Font}"
    echo -e "${Green}此工具将帮助您配置SSH服务的安全选项${Font}\n"
    
    # 设置root登录
    echo -ne "${Green}是否允许root用户通过SSH登录？(yes/no) ${Font}"
    read -r root_login
    
    # 设置密码认证
    echo -ne "${Green}是否允许使用密码认证？(yes/no) ${Font}"
    read -r password_auth
    
    # 设置公钥认证
    echo -ne "${Green}是否允许使用公钥认证？(yes/no) ${Font}"
    read -r pubkey_auth
    
    # 确认设置
    echo -e "\n${Green}您的设置如下：${Font}"
    echo -e "Root登录: $root_login"
    echo -e "密码认证: $password_auth"
    echo -e "公钥认证: $pubkey_auth"
    
    echo -ne "\n${Green}确认应用以上设置？(y/n) ${Font}"
    read -r confirm
    
    if [ "$confirm" = "y" ]; then
        # 应用配置
        apply_config "$root_login" "$password_auth" "$pubkey_auth"
        
        # 重启SSH服务
        restart_ssh_service
        
        # 显示测试提示
        echo -e "\n${GreenBG}[重要安全提示]${Font}"
        echo -e "1. 请打开新终端测试连接，确认正常后再关闭当前会话！"
        echo -e "2. 若连接失败，可使用备份文件还原配置："
        echo -e "   cp $backup_file /etc/ssh/sshd_config"
        echo -e "   systemctl restart $(systemctl list-units --type=service | grep -E 'ssh(d)?\.service' | awk '{print $1}' | head -n 1)"
    else
        echo -e "${RedBG} 操作已取消 ${Font}"
    fi
}

# 执行主程序
main
