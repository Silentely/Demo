#!/bin/bash
## Author: SuperManito
## Fix: Silentely
## Modified: 2026-09-27
## License: GPL-2.0
## Github: https://github.com/SuperManito/LinuxMirrors
## Gitee: https://gitee.com/SuperManito/LinuxMirrors

# 管道输入兼容
if [[ ! -t 0 ]] && { true < /dev/tty; } 2>/dev/null; then
    exec < /dev/tty 2>/dev/null || true
fi

function AuthorSignature() {
    echo -e "\n${GREEN} ------------ 脚本执行结束 ------------ ${PLAIN}\n"
    echo -e '\033[0;1;35;95m┌─\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m─┐\033[0m'
    echo -e '\033[0;1;31;91m│\033[0m   \033[0;1;32;92m__\033[0;1;36;96m__\033[0;1;34;94m_\033[0m                       \033[0;1;34;94m__\033[0m  \033[0;1;31;91m__\033[0;1;33;93m_\033[0m            \033[0;1;33;93m_\033[0m \033[0;1;32;92m_\033[0;1;36;96m__\033[0m      \033[0;1;31;91m│\033[0m'
    echo -e '\033[0;1;33;93m│\033[0m  \033[0;1;32;92m/\033[0m \033[0;1;36;96m_\033[0;1;34;94m__\033[0;1;35;95m/_\033[0;1;31;91m_\033[0m  \033[0;1;33;93m_\033[0;1;32;92m__\033[0;1;36;96m__\033[0;1;34;94m_\033[0m  \033[0;1;35;95m_\033[0;1;31;91m__\033[0m  \033[0;1;32;92m__\033[0;1;36;96m__\033[0;1;34;94m_/\033[0m  \033[0;1;31;91m|/\033[0m  \033[0;1;32;92m/_\033[0;1;36;96m__\033[0m \033[0;1;34;94m_\033[0;1;35;95m__\033[0;1;31;91m__\033[0m  \033[0;1;32;92m(_\033[0;1;36;96m)\033[0m \033[0;1;34;94m/_\033[0;1;35;95m__\033[0;1;31;91m__\033[0m \033[0;1;33;93m│\033[0m'
    echo -e '\033[0;1;32;92m│\033[0m  \033[0;1;36;96m\\\033[0;1;34;94m__\033[0m \033[0;1;35;95m\\\033[0;1;31;91m/\033[0m \033[0;1;33;93m/\033[0m \033[0;1;32;92m/\033[0m \033[0;1;36;96m/\033[0m \033[0;1;34;94m__\033[0m \033[0;1;35;95m\\\033[0;1;31;91m/\033[0m \033[0;1;33;93m_\033[0m \033[0;1;32;92m\\\/\033[0m \033[0;1;36;96m_\033[0;1;34;94m__\033[0;1;35;95m/\033[0m \033[0;1;31;91m/|\033[0;1;33;93m_/\033[0m \033[0;1;32;92m/\033[0m \033[0;1;36;96m_\033[0;1;34;94m__\033[0m \033[0;1;35;95m`/\033[0m \033[0;1;31;91m_\033[0;1;33;93m__\033[0m \033[0;1;32;92m\\/\033[0m \033[0;1;36;96m/\033[0m \033[0;1;34;94m_\033[0;1;35;95m_/\033[0m \033[0;1;31;91m_\033[0;1;33;93m__\033[0m \033[0;1;32;92m\\\\│\033[0m'
    echo -e '\033[0;1;36;96m│\033[0m \033[0;1;34;94m__\033[0;1;35;95m_/\033[0m \033[0;1;31;91m/\033[0m \033[0;1;33;93m/\033[0;1;32;92m_/\033[0m \033[0;1;36;96m/\033[0m \033[0;1;34;94m/\033[0;1;35;95m_/\033[0m \033[0;1;31;91m/\033[0m  \033[0;1;32;92m__\033[0;1;36;96m/\033[0m \033[0;1;34;94m/\033[0m  \033[0;1;35;95m/\033[0m \033[0;1;31;91m/\033[0m  \033[0;1;32;92m/\033[0m \033[0;1;36;96m/\033[0m \033[0;1;34;94m/_\033[0;1;35;95m/\033[0m \033[0;1;31;91m/\033[0m \033[0;1;33;93m/\033[0m \033[0;1;32;92m/\033[0m \033[0;1;36;96m/\033[0m \033[0;1;34;94m/\033[0m \033[0;1;35;95m/_\033[0;1;31;91m/\033[0m \033[0;1;33;93m/_\033[0;1;32;92m/\033[0m \033[0;1;36;96m/│\033[0m'
    echo -e '\033[0;1;34;94m│/\033[0;1;35;95m__\033[0;1;31;91m__\033[0;1;33;93m/\\\033[0;1;32;92m__\033[0;1;36;96m,_\033[0;1;34;94m/\033[0m \033[0;1;35;95m._\033[0;1;31;91m__\033[0;1;33;93m/\\\033[0;1;32;92m__\033[0;1;36;96m_/\033[0;1;34;94m_/\033[0m  \033[0;1;31;91m/_\033[0;1;33;93m/\033[0m  \033[0;1;32;92m/\033[0;1;36;96m_/\033[0;1;34;94m\\_\033[0;1;35;95m_,\033[0;1;31;91m_/\033[0;1;33;93m_/\033[0m \033[0;1;32;92m/\033[0;1;36;96m_/\033[0;1;34;94m_/\033[0;1;35;95m\\_\033[0;1;31;91m_/\033[0;1;33;93m\\_\033[0;1;32;92m__\033[0;1;36;96m_/\033[0m \033[0;1;34;94m│\033[0m'
    echo -e '\033[0;1;35;95m│\033[0m          \033[0;1;34;94m/\033[0;1;35;95m_/\033[0m                                               \033[0;1;35;95m│\033[0m'
    echo -e '\033[0;1;31;91m└──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──\033[0;1;31;91m──\033[0;1;33;93m──\033[0;1;32;92m──\033[0;1;36;96m──\033[0;1;34;94m──\033[0;1;35;95m──┘\033[0m\n'

    echo -e " \033[1;34m官方网站\033[0m https://supermanito.github.io/LinuxMirrors\n"
}

## 定义系统判定变量
DebianRelease="lsb_release"
ARCH=$(uname -m)
SYSTEM_DEBIAN="Debian"
SYSTEM_UBUNTU="Ubuntu"
SYSTEM_KALI="Kali"
SYSTEM_REDHAT="RedHat"
SYSTEM_RHEL="RedHat"
SYSTEM_CENTOS="CentOS"
SYSTEM_FEDORA="Fedora"

## 定义目录和文件
LinuxRelease=/etc/os-release
RedHatRelease=/etc/redhat-release
DebianVersion=/etc/debian_version
DebianSourceList=/etc/apt/sources.list
DebianExtendListDir=/etc/apt/sources.list.d
RedHatReposDir=/etc/yum.repos.d
SelinuxConfig=/etc/selinux/config

## 定义 Docker 相关变量
DockerSourceList=$DebianExtendListDir/docker.list
DockerRepo=$RedHatReposDir/download.docker.com_linux_*.repo
DockerDir=/etc/docker
DockerConfig=$DockerDir/daemon.json
DockerConfigBackup=$DockerDir/daemon.json.bak
DockerCompose=/usr/local/bin/docker-compose
DockerVersionFile=docker-version.txt
DockerCEVersionFile=docker-ce-version.txt
DockerCECLIVersionFile=docker-ce-cli-version.txt
PROXY_URL=https://get.daocloud.io/
DOCKER_COMPOSE_VERSION=v2.24.5

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'
BOLD='\033[1m'
SUCCESS='[\033[32mOK\033[0m]'
COMPLETE='[\033[32mDONE\033[0m]'
WARN='[\033[33mWARN\033[0m]'
ERROR='[\033[31mERROR\033[0m]'
WORKING='[\033[34m*\033[0m]'

## 组合函数
function Combin_Function() {
    PermissionJudgment
    NetWorkJudgment
    EnvJudgment
    ChooseMirrors
    InstallationEnvironment
    ConfigureDockerCEMirror
    DockerEngine
    DockerCompose
    ShowVersion
    AuthorSignature
}

## 系统判定变量
function EnvJudgment() {
    ## 判定当前系统基于 Debian or RedHat
    if [ -s $RedHatRelease ]; then
        SYSTEM_FACTIONS=${SYSTEM_REDHAT}
    elif [ -s $DebianVersion ]; then
        SYSTEM_FACTIONS=${SYSTEM_DEBIAN}
    elif grep -qiE 'ID_LIKE=.*(debian|ubuntu)' "$LinuxRelease" 2>/dev/null; then
        SYSTEM_FACTIONS=${SYSTEM_DEBIAN}
    elif grep -qiE 'ID_LIKE=.*(rhel|fedora|centos)' "$LinuxRelease" 2>/dev/null; then
        SYSTEM_FACTIONS=${SYSTEM_REDHAT}
    else
        echo -e "\n$ERROR 无法判断当前运行环境，请先确认本脚本针对当前操作系统是否适配！\n"
        exit 1
    fi
    ## 定义系统名称
    SYSTEM_NAME=$(grep -E "^NAME=" "$LinuxRelease" | awk -F '=' '{print$2}' | sed "s/['\"]//g")
    ## 定义系统版本号
    SYSTEM_VERSION_NUMBER=$(grep -E "VERSION_ID=" "$LinuxRelease" | awk -F '=' '{print$2}' | sed "s/['\"]//g")
    ## 判定系统名称、版本、版本号
    case ${SYSTEM_FACTIONS} in
    Debian)
        SYSTEM_JUDGMENT=$(${DebianRelease} -is 2>/dev/null || grep -E "^ID=" "$LinuxRelease" | cut -d= -f2 | sed 's/"//g')
        SYSTEM_VERSION=$(${DebianRelease} -cs 2>/dev/null || grep -E "^VERSION_CODENAME=" "$LinuxRelease" | cut -d= -f2 | sed 's/"//g')
        ;;
    RedHat)
        local os_id
        os_id=$(grep -E "^ID=" "$LinuxRelease" | cut -d= -f2 | sed 's/["\x27]//g' | tr '[:upper:]' '[:lower:]')
        if [[ "$os_id" == "fedora" ]]; then
            SYSTEM_JUDGMENT="fedora"
            SOURCE_BRANCH="fedora"
        else
            # CentOS, RHEL, Rocky Linux, AlmaLinux, Oracle Linux 均兼容官方 centos docker-ce repo
            SYSTEM_JUDGMENT="centos"
            SOURCE_BRANCH="centos"
        fi
        CENTOS_VERSION=$(echo ${SYSTEM_VERSION_NUMBER} | cut -c1)
        ;;
    esac
    ## 判定系统处理器架构
    case ${ARCH} in
    x86_64)
        SYSTEM_ARCH="x86_64"
        SOURCE_ARCH="amd64"
        ;;
    aarch64|arm64)
        SYSTEM_ARCH="ARM64"
        SOURCE_ARCH="arm64"
        ;;
    armv7l)
        SYSTEM_ARCH="ARMv7"
        SOURCE_ARCH="armhf"
        ;;
    armv6l)
        SYSTEM_ARCH="ARMv6"
        SOURCE_ARCH="armhf"
        ;;
    i386 | i686)
        SYSTEM_ARCH="x86_32"
        echo -e "\n${RED}---------- Docker Engine 不支持安装在 x86_32 架构的环境上！ ----------${PLAIN}\n"
        exit 1
        ;;
    *)
        SYSTEM_ARCH=${ARCH}
        SOURCE_ARCH=armhf
        ;;
    esac
    ## 定义软件源分支名称 (若 Debian 系则小写转换)
    if [[ "${SYSTEM_FACTIONS}" == "Debian" ]]; then
        SOURCE_BRANCH=$(echo "${SYSTEM_JUDGMENT}" | tr '[:upper:]' '[:lower:]')
    fi
    ## 定义软件源同步/更新文字
    case ${SYSTEM_FACTIONS} in
    Debian)
        SYNC_TXT="更新"
        ;;
    RedHat)
        SYNC_TXT="同步"
        ;;
    esac
}

## 基础环境判断
function PermissionJudgment() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n$ERROR 权限不足，请使用 Root 用户运行本脚本！\n"
        exit 1
    fi
}
function NetWorkJudgment() {
    if ! ping -c 1 -W 3 223.5.5.5 >/dev/null 2>&1 && ! ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1; then
        echo -e "\n${RED} ----- 网络连接检测失败，请检查网络连接！ ----- ${PLAIN}\n"
        exit 1
    fi
}

## 关闭防火墙 (仅 RedHat 系)
function CloseFirewall() {
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        systemctl disable --now firewalld >/dev/null 2>&1
        [ -s $SelinuxConfig ] && sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" $SelinuxConfig && setenforce 0 >/dev/null 2>&1
    fi
}

## 环境安装
function InstallationEnvironment() {
    case ${SYSTEM_FACTIONS} in
    Debian)
        sed -i '/docker-ce/d' $DebianSourceList
        rm -rf $DockerSourceList
        ;;
    RedHat)
        rm -rf $DockerRepo
        ;;
    esac
    echo -e "\n$WORKING 开始${SYNC_TXT}软件源...\n"
    case ${SYSTEM_FACTIONS} in
    Debian)
        apt-get update
        ;;
    RedHat)
        yum makecache
        ;;
    esac
    VERI_CACHE=$?
    if [ ${VERI_CACHE} -ne 0 ]; then
        echo -e "\n$ERROR 软件源${SYNC_TXT}失败，请检查网络或软件源配置！\n"
        exit 1
    fi
    echo -e "\n$COMPLETE 软件源${SYNC_TXT}结束\n"
    case ${SYSTEM_FACTIONS} in
    Debian)
        apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        ;;
    RedHat)
        # 支持 yum 与 dnf (针对 Rocky/Alma/CentOS 8/9)
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y yum-utils
        else
            yum install -y yum-utils
        fi
        CloseFirewall
        ;;
    esac
}

## 选择镜像源
function ChooseMirrors() {
    clear
    echo -e '+---------------------------------------------------+'
    echo -e '|      欢迎使用 Docker CE 容器引擎一键安装脚本      |'
    echo -e '+---------------------------------------------------+'
    echo -e ''
    echo -e ' 运行环境  '"${SYSTEM_NAME} ${SYSTEM_VERSION_NUMBER} ${SYSTEM_ARCH}"''
    echo -e ' 系统时间  '"$(date "+%Y-%m-%d %H:%M:%S")"''
    echo -e ''
    echo -e ' ───────────────────────────────────────────────────'
    echo -e ''
    echo -e '       1. 官方源(默认)'
    echo -e '       2. 阿里云'
    echo -e '       3. 腾讯云'
    echo -e '       4. 华为云'
    echo -e '       5. 微软 Azure 中国'
    echo -e '       6. 网易'
    echo -e '       7. 清华大学'
    echo -e '       8. 北京外国语大学'
    echo -e '       9. 浙江大学'
    echo -e '      10. 南京大学'
    echo -e '      11. 中科大'
    echo -e '      12. 重庆大学'
    echo -e '      13. 上海交通大学'
    echo -e '      14. 哈尔滨工业大学'
    echo -e '      15. 兰州大学'
    echo -e ''
    echo -e ' ───────────────────────────────────────────────────'
    echo -e ''
    CHOICE=$(echo -e '\n\033[33m└── 请选择你想使用的 Docker CE 镜像源 [ 1-15 ]：\033[0m')
    read -p "${CHOICE}" INPUT
    case $INPUT in
    2)
        SOURCE="mirrors.aliyun.com/docker-ce"
        ;;
    3)
        SOURCE="mirrors.tencent.com/docker-ce"
        ;;
    4)
        SOURCE="repo.huaweicloud.com/docker-ce"
        ;;
    5)
        SOURCE="mirror.azure.cn/docker-ce"
        ;;
    6)
        SOURCE="mirrors.163.com/docker-ce"
        ;;
    7)
        SOURCE="mirrors.tuna.tsinghua.edu.cn/docker-ce"
        ;;
    8)
        SOURCE="mirrors.bfsu.edu.cn/docker-ce"
        ;;
    9)
        SOURCE="mirrors.zju.edu.cn/docker-ce"
        ;;
    10)
        SOURCE="mirrors.nju.edu.cn/docker-ce"
        ;;
    11)
        SOURCE="mirrors.ustc.edu.cn/docker-ce"
        ;;
    12)
        SOURCE="mirrors.cqu.edu.cn/docker-ce"
        ;;
    13)
        SOURCE="mirror.sjtu.edu.cn/docker-ce"
        ;;
    14)
        SOURCE="mirrors.hit.edu.cn/docker-ce"
        ;;
    15)
        SOURCE="mirror.lzu.edu.cn/docker-ce"
        ;;
    *)
        SOURCE="download.docker.com"
        ;;
    esac
}

## 配置 Docker CE 镜像源
function ConfigureDockerCEMirror() {
    case ${SYSTEM_FACTIONS} in
    Debian)
        # 现代安全标准：使用 /etc/apt/keyrings/docker.gpg (Debian 12/Ubuntu 24.04 官方要求)
        install -m 0755 -d /etc/apt/keyrings
        if curl -fsSL "https://${SOURCE}/linux/${SOURCE_BRANCH}/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
            chmod a+r /etc/apt/keyrings/docker.gpg
            echo "deb [arch=${SOURCE_ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://${SOURCE}/linux/${SOURCE_BRANCH} ${SYSTEM_VERSION} stable" > $DockerSourceList
        else
            # 向下兼容回退
            curl -fsSL "https://${SOURCE}/linux/${SOURCE_BRANCH}/gpg" | apt-key add - >/dev/null 2>&1
            echo "deb [arch=${SOURCE_ARCH}] https://${SOURCE}/linux/${SOURCE_BRANCH} ${SYSTEM_VERSION} stable" > $DockerSourceList
        fi
        apt-get update
        ;;
    RedHat)
        yum-config-manager --add-repo https://${SOURCE}/linux/${SOURCE_BRANCH}/docker-ce.repo
        if [ "$SOURCE" != "download.docker.com" ]; then
            sed -i "s#https://download.docker.com#https://${SOURCE}#g" $DockerRepo
        fi
        yum makecache
        ;;
    esac
}

## 安装 Docker Engine
function DockerEngine() {
    echo -e "\n$WORKING 开始安装 Docker Engine...\n"
    case ${SYSTEM_FACTIONS} in
    Debian)
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        ;;
    RedHat)
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        else
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        ;;
    esac
    systemctl enable --now docker
}

## 安装 Docker Compose
function DockerCompose() {
    # 优先检测官方自带的 compose plugin
    if docker compose version >/dev/null 2>&1; then
        echo -e "\n$COMPLETE 检测到 Docker Compose Plugin (v2) 已随引擎安装就绪。"
        # 兼容旧版调用习惯，创建 /usr/local/bin/docker-compose 软链接
        if [[ ! -x "$DockerCompose" ]]; then
            cat > "$DockerCompose" << 'EOF'
#!/bin/sh
exec docker compose "$@"
EOF
            chmod +x "$DockerCompose" 2>/dev/null || true
        fi
        return 0
    fi

    echo -e "\n$WORKING 正在部署 Docker Compose 官方多架构独立二进制...\n"
    local compose_arch=""
    case ${ARCH} in
        x86_64)       compose_arch="x86_64" ;;
        aarch64|arm64) compose_arch="aarch64" ;;
        armv7l)       compose_arch="armv7" ;;
        armv6l)       compose_arch="armv6" ;;
        *)            compose_arch="${ARCH}" ;;
    esac

    local download_url="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${compose_arch}"
    if curl -fsSL --connect-timeout 10 -o "$DockerCompose" "$download_url" 2>/dev/null || \
       curl -fsSL --connect-timeout 10 -o "$DockerCompose" "${PROXY_URL}${download_url}" 2>/dev/null; then
        chmod +x "$DockerCompose"
        echo -e "\n$COMPLETE Docker Compose 二进制部署成功: $($DockerCompose version 2>/dev/null)\n"
    else
        echo -e "\n$WARN 二进制下载失败，尝试通过系统包管理器安装 docker-compose-plugin...\n"
        case ${SYSTEM_FACTIONS} in
            Debian) apt-get install -y docker-compose-plugin 2>/dev/null ;;
            RedHat) yum install -y docker-compose-plugin 2>/dev/null ;;
        esac
    fi
}

## 显示版本信息
function ShowVersion() {
    echo -e "\n${GREEN}================== 安装版本检验 ==================${PLAIN}"
    if command -v docker >/dev/null 2>&1; then
        docker --version
    else
        echo -e "${RED}Docker 安装失败，请检查安装日志。${PLAIN}"
    fi

    if docker compose version >/dev/null 2>&1; then
        docker compose version
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose --version
    fi
    echo -e "${GREEN}==================================================${PLAIN}\n"
}

Combin_Function
