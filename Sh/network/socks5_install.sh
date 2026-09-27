#!/bin/bash
#
#   Dante Socks5 Server AutoInstall
#   -- Owner:       https://www.inet.no/dante
#   -- Provider:    https://sockd.info
#   -- Author:      Lozy
#

# Check if user is root
if [ "$(id -u)" != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install"
    exit 1
fi

REQUEST_SERVER="https://raw.githubusercontent.com/Lozy/danted/master"
SCRIPT_SERVER="https://public.sockd.info"
SYSTEM_RECOGNIZE=""

if [ "${1:-}" = "--no-github" ]; then
    REQUEST_SERVER=${SCRIPT_SERVER}
    shift
fi

if [ -s "/etc/os-release" ]; then
    os_name=$(sed -n 's/PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release)

    if echo "${os_name}" | grep -Eiq 'Debian|Ubuntu|Kali|Armbian|Pop!_OS|Mint'; then
        printf "Current OS: %s\n" "${os_name}"
        SYSTEM_RECOGNIZE="debian"
    elif echo "${os_name}" | grep -Eiq 'CentOS|Red Hat|RHEL|Rocky|AlmaLinux|Fedora'; then
        printf "Current OS: %s\n" "${os_name}"
        SYSTEM_RECOGNIZE="centos"
    else
        printf "Current OS: %s is not supported.\n" "${os_name}"
    fi
elif [ -s "/etc/issue" ]; then
    if grep -Eiq 'CentOS|Red Hat|Rocky|AlmaLinux' /etc/issue; then
        printf "Current OS: %s\n" "$(grep -Ei 'CentOS|Red Hat' /etc/issue)"
        SYSTEM_RECOGNIZE="centos"
    elif grep -Eiq 'Debian|Ubuntu' /etc/issue; then
        SYSTEM_RECOGNIZE="debian"
    else
        printf "+++++++++++++++++++++++\n"
        cat /etc/issue
        printf "+++++++++++++++++++++++\n"
        printf "[Error] Current OS is not available to support.\n"
    fi
else
    printf "[Error] (/etc/os-release) OR (/etc/issue) not exist!\n"
    printf "[Error] Current OS is not available to support.\n"
fi

if [ -n "$SYSTEM_RECOGNIZE" ]; then
    installer_url="${REQUEST_SERVER}/install_${SYSTEM_RECOGNIZE}.sh"
    echo "Downloading and executing installer from: $installer_url"
    if command -v curl &>/dev/null; then
        curl -fsSL "$installer_url" | bash -s -- "$@"
    elif command -v wget &>/dev/null; then
        wget -qO- --no-check-certificate "$installer_url" | bash -s -- "$@"
    else
        echo "Error: neither curl nor wget found. Please install one of them."
        exit 1
    fi
else
    printf "[Error] Installing terminated\n"
    exit 1
fi

exit 0
