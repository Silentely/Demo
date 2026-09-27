#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: block-ips.sh
# 功能:     Linux VPS 一键屏蔽/解除指定国家所有 IP 访问 (极速 ipset restore 版)
# ==============================================================================

Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Font="\033[0m"

# 管道输入兼容
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

root_need(){
    if [[ $EUID -ne 0 ]]; then
        echo -e "${Red}Error: This script must be run as root!${Font}" >&2
        exit 1
    fi
}

check_ipset(){
    if command -v ipset &>/dev/null; then
        return 0
    fi
    echo -e "${Yellow}正在安装 ipset...${Font}"
    if command -v apt-get &>/dev/null; then
        apt-get update -y && apt-get install -y ipset
    elif command -v dnf &>/dev/null; then
        dnf install -y ipset
    elif command -v yum &>/dev/null; then
        yum install -y ipset
    elif command -v pacman &>/dev/null; then
        pacman -S --noconfirm ipset
    fi
}

block_ipset(){
    check_ipset
    echo -e "${Green}请输入需要封禁的国家代码，如 cn (中国)，注意为两位小写字母：${Font}"
    read -rp "国家代码: " GEOIP
    GEOIP=$(echo "$GEOIP" | tr '[:upper:]' '[:lower:]' | xargs)
    if [[ -z "$GEOIP" ]]; then
        echo -e "${Red}国家代码不能为空！${Font}"
        return 1
    fi
    if ! [[ "$GEOIP" =~ ^[a-z]{2}$ ]]; then
        echo -e "${Red}国家代码格式错误！必须为两位 ISO 小写字母（例如 cn, us, ru）。${Font}"
        return 1
    fi

    echo -e "${Green}正在下载 $GEOIP 的 IP 段数据...${Font}"
    local zone_file="/tmp/${GEOIP}.zone"
    rm -f "$zone_file"

    local url="https://www.ipdeny.com/ipblocks/data/countries/${GEOIP}.zone"
    if command -v curl &>/dev/null; then
        curl -fsSL --connect-timeout 5 --max-time 15 -o "$zone_file" "$url" || true
    fi
    if [[ ! -s "$zone_file" ]] && command -v wget &>/dev/null; then
        wget -q --timeout=15 -O "$zone_file" "$url" || true
    fi

    if [ ! -s "$zone_file" ]; then
        echo -e "${Red}下载失败，请检查国家代码是否有效！${Font}"
        echo -e "官方国家代码列表：https://www.ipdeny.com/ipblocks/data/countries/"
        return 1
    fi

    echo -e "${Green}正在通过 ipset 极速载入 IP 规则库...${Font}"
    local tmp_set="${GEOIP}_tmp"
    ipset create "$tmp_set" hash:net -exist 2>/dev/null || true
    ipset flush "$tmp_set" 2>/dev/null || true
    {
        while read -r cidr; do
            [[ -n "$cidr" && ! "$cidr" =~ ^# ]] && echo "add $tmp_set $cidr -exist"
        done < "$zone_file"
    } | ipset restore

    rm -f "$zone_file"

    ipset create "$GEOIP" hash:net -exist 2>/dev/null || true
    ipset swap "$tmp_set" "$GEOIP" 2>/dev/null || true
    ipset destroy "$tmp_set" 2>/dev/null || true

    # 添加 iptables 过滤规则 (避免重复添加)
    if ! iptables -C INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP 2>/dev/null; then
        iptables -I INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP
    fi
    if ! iptables -C INPUT -p udp -m set --match-set "$GEOIP" src -j DROP 2>/dev/null; then
        iptables -I INPUT -p udp -m set --match-set "$GEOIP" src -j DROP
    fi

    echo -e "${Green}国家 ($GEOIP) 的 IP 封禁已生效！${Font}"
}

unblock_ipset(){
    echo -e "${Green}请输入需要解封的国家代码，如 cn：${Font}"
    read -rp "国家代码: " GEOIP
    GEOIP=$(echo "$GEOIP" | tr '[:upper:]' '[:lower:]' | xargs)

    if ipset list -n | grep -qw "$GEOIP"; then
        iptables -D INPUT -p tcp -m set --match-set "$GEOIP" src -j DROP 2>/dev/null || true
        iptables -D INPUT -p udp -m set --match-set "$GEOIP" src -j DROP 2>/dev/null || true
        ipset destroy "$GEOIP" 2>/dev/null || true
        echo -e "${Green}国家 ($GEOIP) 的 IP 已成功解封！${Font}"
    else
        echo -e "${Red}未在封禁列表中找到国家 ($GEOIP)！${Font}"
    fi
}

main(){
    root_need
    clear
    echo "====================================================="
    echo "  Linux VPS 一键屏蔽/解除指定国家所有 IP (极速版)"
    echo "====================================================="
    echo "  1. 屏蔽指定国家 IP"
    echo "  2. 解除屏蔽指定国家 IP"
    echo "  0. 退出脚本"
    echo "====================================================="
    read -rp "请输入选项编号 [0-2]: " num
    case "$num" in
        1)
            block_ipset
            ;;
        2)
            unblock_ipset
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${Red}请输入正确的数字 [0-2]${Font}"
            exit 1
            ;;
    esac
}

main "$@"
