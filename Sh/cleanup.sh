#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[1;34m'
NC='\033[0m' # 恢复默认

divider() {
  echo -e "${BLUE}============================================================${NC}"
}

banner() {
  echo -e "${CYAN}"
  echo "   _____ _           _             "
  echo "  / ____| |         | |            "
  echo " | |    | | ___  ___| |_ ___  _ __ "
  echo " | |    | |/ _ \/ __| __/ _ \| '__|"
  echo " | |____| |  __/ (__| || (_) | |   "
  echo "  \_____|_|\___|\___|\__\___/|_|   "
  echo -e "${NC}"
}

pause() {
  read -rp "$(echo -e "${YELLOW}按回车键继续...${NC}")"
}

# 进度条动画
progress_bar() {
  local duration=${1:-10}
  local fill="▓"
  local empty="░"
  local width=36
  for ((i=0; i<=duration; i++)); do
    percent=$(( i * 100 / duration ))
    filled=$(( i * width / duration ))
    empty_count=$(( width - filled ))
    bar=$(printf "%0.s$fill" $(seq 1 $filled))
    bar+=$(printf "%0.s$empty" $(seq 1 $empty_count))
    echo -ne "\r${CYAN}[$bar] $percent%${NC}"
    sleep 0.10
  done
  echo
}

# 旋转指针动画
spinner() {
  local pid=$!
  local delay=0.08
  local spinstr='|/-\'
  while ps -p $pid &>/dev/null; do
    temp=${spinstr#?}
    printf "\r${YELLOW}[%c] 正在处理中...${NC}" "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
  done
  printf "\r"
}

# 系统垃圾清理函数
clean_system() {
  divider
  echo -e "${YELLOW}开始系统垃圾清理...${NC}"
  progress_bar 20
  {
    apt-get clean 2>/dev/null
    yum clean all 2>/dev/null
    dnf clean all 2>/dev/null
    rm -rf /var/lib/apt/lists/* /var/backups/* /var/log/apt/* /var/log/sysstat/*
    rm -rf /var/log/journal/ /var/log/private/* /var/log/runit/*
    rm -rf /var/cache/yum/* /var/cache/dnf/* /var/cache/apt/*
    rm -rf /tmp/* /var/tmp/* /var/cache/* /var/mail/* /media/*
    find /tmp -type f -delete 2>/dev/null
    find /var/tmp -type f -delete 2>/dev/null
    for pattern in "*.ucf-dist" "*~" "*-old" "*.bak" "*.swp" "*.tmp" "*.log.[0-9]*" "*.core"; do
      find / -type f -name "$pattern" -exec rm -f {} + 2>/dev/null
    done
    find / -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null
    find / -type f -name "*.pyc" -exec rm -f {} + 2>/dev/null
    find / -type d -name "node_modules" -exec rm -rf {} + 2>/dev/null
    find / -type d -name "target" -exec rm -rf {} + 2>/dev/null
    rm -rf ~/Downloads/* ~/.cache/* ~/.npm/* ~/.yarn/* ~/.m2/repository/* ~/.local/share/Trash/*
    sleep 1
  } & spinner
  echo -e "${GREEN}系统垃圾文件清理完成!${NC}"
  divider
}

# Docker垃圾清理函数
clean_docker() {
  divider
  if command -v docker >/dev/null 2>&1; then
    echo -e "${YELLOW}正在清理无用的Docker镜像、容器、网络和卷...${NC}"
    progress_bar 15
    {
      docker system prune -af --volumes
      sleep 1
    } & spinner
    echo -e "${GREEN}Docker垃圾已清理完成!${NC}"
  else
    echo -e "${RED}未检测到docker命令，跳过Docker清理。${NC}"
  fi
  divider
}

# 旧内核清理函数
clean_kernel() {
  divider
  echo -e "${YELLOW}正在清理旧的系统内核...${NC}"
  progress_bar 12
  CURRENT_KERNEL=$(uname -r)
  {
    if command -v dpkg >/dev/null 2>&1; then
      OLD_IMAGES=$(dpkg -l | awk '/linux-image-[0-9]/{print $2}' | grep -v "$CURRENT_KERNEL")
      OLD_HEADERS=$(dpkg -l | awk '/linux-headers-[0-9]/{print $2}' | grep -v "$CURRENT_KERNEL")
      if [[ -n "$OLD_IMAGES" || -n "$OLD_HEADERS" ]]; then
        echo -e "${CYAN}检测到旧内核：${NC}"
        echo -e "${YELLOW}${OLD_IMAGES}${NC}"
        apt-get -y purge $OLD_IMAGES $OLD_HEADERS
        echo -e "${GREEN}旧内核清理完成!${NC}"
      else
        echo -e "${GREEN}没有可清理的旧内核。${NC}"
      fi
    elif command -v rpm >/dev/null 2>&1; then
      OLD_KERNELS=$(rpm -q kernel | grep -v "$CURRENT_KERNEL")
      if [[ -n "$OLD_KERNELS" ]]; then
        echo -e "${CYAN}检测到旧内核：${NC}"
        echo -e "${YELLOW}${OLD_KERNELS}${NC}"
        echo "$OLD_KERNELS" | xargs -r yum -y remove
        echo -e "${GREEN}旧内核清理完成!${NC}"
      else
        echo -e "${GREEN}没有可清理的旧内核。${NC}"
      fi
    else
      echo -e "${RED}未知的包管理器，无法自动清理旧内核。${NC}"
    fi
    sleep 1
  } & spinner
  divider
}

# 清理旧snap版本文件函数
clean_snap() {
  divider
  if command -v snap >/dev/null 2>&1; then
    echo -e "${YELLOW}正在查找并清理旧的snap版本文件...${NC}"
    progress_bar 10
    {
      SNAP_OLD=$(snap list --all | awk '/disabled/{print $1, $2}')
      if [[ -n "$SNAP_OLD" ]]; then
        snap list --all | awk '/disabled/{print $1, $2}' | while read snapname version; do
          echo -e "${CYAN}移除 $snapname 版本 $version ...${NC}"
          snap remove "$snapname" --revision="$version"
        done
        echo -e "${GREEN}旧snap版本文件清理完成!${NC}"
      else
        echo -e "${GREEN}没有可清理的旧snap版本文件。${NC}"
      fi
      sleep 1
    } & spinner
  else
    echo -e "${RED}未检测到snap命令，跳过snap清理。${NC}"
  fi
  divider
}

# 旧软件包自动清理
clean_old_packages() {
  divider
  echo -e "${YELLOW}正在清理旧的软件包和残留配置...${NC}"
  progress_bar 10
  {
    if command -v apt-get >/dev/null 2>&1; then
      apt-get autoremove -y
      RC_PKGS=$(dpkg -l | awk '/^rc/ { print $2 }')
      if [[ -n "$RC_PKGS" ]]; then
        apt-get purge -y $RC_PKGS
      fi
    elif command -v yum >/dev/null 2>&1; then
      yum autoremove -y
    elif command -v dnf >/dev/null 2>&1; then
      dnf autoremove -y
    fi
    sleep 1
  } & spinner
  echo -e "${GREEN}旧软件包清理完成!${NC}"
  divider
}

# 软件源有效性检测
check_old_sources() {
  divider
  echo -e "${YELLOW}正在检查软件源配置文件中可能失效的源...${NC}"
  progress_bar 8
  
  # 创建临时文件保存失效源信息
  invalid_sources_file=$(mktemp)
  
  {
    # 检查apt源
    if [ -f /etc/apt/sources.list ]; then
      grep -E '^deb ' /etc/apt/sources.list | while read -r line; do
        url=$(echo "$line" | awk '{print $2}')
        if ! curl -sf --max-time 5 "$url" >/dev/null; then
          echo -e "${RED}检测到失效源: $url (请手动检查)${NC}"
          echo "sources.list:$line" >> "$invalid_sources_file"
        fi
      done
      for f in /etc/apt/sources.list.d/*.list; do
        [ -e "$f" ] || continue
        grep -E '^deb ' "$f" | while read -r line; do
          url=$(echo "$line" | awk '{print $2}')
          if ! curl -sf --max-time 5 "$url" >/dev/null; then
            echo -e "${RED}检测到失效源: $url (请手动检查)${NC}"
            echo "$f:$line" >> "$invalid_sources_file"
          fi
        done
      done
    fi
    # 检查yum/dnf源
    if [ -d /etc/yum.repos.d/ ]; then
      for f in /etc/yum.repos.d/*.repo; do
        [ -e "$f" ] || continue
        grep -E '^baseurl=' "$f" | while read -r line; do
          url=$(echo "$line" | cut -d= -f2)
          if ! curl -sf --max-time 5 "$url" >/dev/null; then
            echo -e "${RED}检测到失效源: $url (请手动检查)${NC}"
            echo "$f:$line" >> "$invalid_sources_file"
          fi
        done
      done
    fi
    sleep 1
  } & spinner
  
  # 检查是否有失效源
  if [ -s "$invalid_sources_file" ]; then
    echo -e "${YELLOW}发现失效源。您可以选择手动检查或使用'自动清理失效源'功能。${NC}"
  else
    echo -e "${GREEN}未检测到失效源，所有软件源正常。${NC}"
    rm -f "$invalid_sources_file"
  fi
  
  divider
}

# 自动清理失效源
auto_clean_sources() {
  divider
  echo -e "${YELLOW}开始自动清理失效源...${NC}"
  progress_bar 10
  
  # 检查临时文件是否存在
  invalid_sources_file=$(find /tmp -name "tmp.*" -type f -mmin -60 | xargs grep -l "sources.list:" 2>/dev/null | head -1)
  
  if [ -z "$invalid_sources_file" ] || [ ! -s "$invalid_sources_file" ]; then
    # 如果没有之前检测的结果，重新进行检测
    invalid_sources_file=$(mktemp)
    {
      # 检查apt源
      if [ -f /etc/apt/sources.list ]; then
        grep -E '^deb ' /etc/apt/sources.list | while read -r line; do
          url=$(echo "$line" | awk '{print $2}')
          if ! curl -sf --max-time 5 "$url" >/dev/null; then
            echo "sources.list:$line" >> "$invalid_sources_file"
          fi
        done
        for f in /etc/apt/sources.list.d/*.list; do
          [ -e "$f" ] || continue
          grep -E '^deb ' "$f" | while read -r line; do
            url=$(echo "$line" | awk '{print $2}')
            if ! curl -sf --max-time 5 "$url" >/dev/null; then
              echo "$f:$line" >> "$invalid_sources_file"
            fi
          done
        done
      fi
      # 检查yum/dnf源
      if [ -d /etc/yum.repos.d/ ]; then
        for f in /etc/yum.repos.d/*.repo; do
          [ -e "$f" ] || continue
          grep -E '^baseurl=' "$f" | while read -r line; do
            url=$(echo "$line" | cut -d= -f2)
            if ! curl -sf --max-time 5 "$url" >/dev/null; then
              echo "$f:$line" >> "$invalid_sources_file"
            fi
          done
        done
      fi
    } & spinner
  fi
  
  # 处理检测到的失效源
  if [ -s "$invalid_sources_file" ]; then
    echo -e "${CYAN}检测到以下失效源:${NC}"
    cat "$invalid_sources_file" | while read -r entry; do
      file=$(echo "$entry" | cut -d: -f1)
      line=$(echo "$entry" | cut -d: -f2-)
      
      # 针对包含"[arch=amd64"的特殊处理
      if echo "$line" | grep -q "\[arch=amd64"; then
        echo -e "${YELLOW}正在处理文件 $file 中的架构相关配置...${NC}"
        # 创建临时文件
        tmp_file=$(mktemp)
        # 过滤掉有问题的行，或修改行
        if [ "$file" == "sources.list" ]; then
          grep -v "$line" /etc/apt/sources.list > "$tmp_file"
          echo -e "${GREEN}已从 /etc/apt/sources.list 中删除失效源:${NC}"
          echo -e "${RED}$line${NC}"
          # 备份原文件并替换
          cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)
          mv "$tmp_file" /etc/apt/sources.list
          chmod 644 /etc/apt/sources.list
        else
          grep -v "$line" "$file" > "$tmp_file"
          echo -e "${GREEN}已从 $file 中删除失效源:${NC}"
          echo -e "${RED}$line${NC}"
          # 备份原文件并替换
          cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
          mv "$tmp_file" "$file"
          chmod 644 "$file"
        fi
      else
        # 其他类型的失效源处理
        echo -e "${YELLOW}正在处理失效源: $line${NC}"
        tmp_file=$(mktemp)
        if [ "$file" == "sources.list" ]; then
          grep -v "$line" /etc/apt/sources.list > "$tmp_file"
          echo -e "${GREEN}已从 /etc/apt/sources.list 中删除失效源:${NC}"
          echo -e "${RED}$line${NC}"
          # 备份原文件并替换
          cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)
          mv "$tmp_file" /etc/apt/sources.list
          chmod 644 /etc/apt/sources.list
        else
          grep -v "$line" "$file" > "$tmp_file"
          echo -e "${GREEN}已从 $file 中删除失效源:${NC}"
          echo -e "${RED}$line${NC}"
          # 备份原文件并替换
          cp "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
          mv "$tmp_file" "$file"
          chmod 644 "$file"
        fi
      fi
    done
    
    echo -e "${GREEN}失效源清理完成! 原始文件已备份为 .bak.时间戳 格式。${NC}"
  else
    echo -e "${GREEN}未检测到失效源，无需清理。${NC}"
  fi
  
  # 清理临时文件
  rm -f "$invalid_sources_file"
  
  divider
}

# 主循环
while true; do
  clear
  banner
  divider
  echo -e "${BLUE}请选择清理操作：${NC}"
  echo -e "${CYAN}1) 一键清理（系统+Docker+旧内核+旧snap+旧包+源检测）${NC}"
  echo -e "${CYAN}2) 仅清理Docker无用镜像/容器${NC}"
  echo -e "${CYAN}3) 仅清理旧内核${NC}"
  echo -e "${CYAN}4) 仅清理系统垃圾文件${NC}"
  echo -e "${CYAN}5) 仅清理旧snap版本文件${NC}"
  echo -e "${CYAN}6) 仅清理旧软件包${NC}"
  echo -e "${CYAN}7) 仅检测失效软件源${NC}"
  echo -e "${CYAN}8) 自动清理失效软件源${NC}"
  echo -e "${RED}0) 退出${NC}"
  divider
  read -rp "$(echo -e "${YELLOW}请输入选项(0-8): ${NC}")" choice
  case $choice in
    1)
      clean_system
      clean_docker
      clean_kernel
      clean_snap
      clean_old_packages
      check_old_sources
      read -rp "$(echo -e "${YELLOW}是否要自动清理检测到的失效源? (y/n): ${NC}")" clean_choice
      if [[ "$clean_choice" == "y" || "$clean_choice" == "Y" ]]; then
        auto_clean_sources
      fi
      pause
      ;;
    2)
      clean_docker
      pause
      ;;
    3)
      clean_kernel
      pause
      ;;
    4)
      clean_system
      pause
      ;;
    5)
      clean_snap
      pause
      ;;
    6)
      clean_old_packages
      pause
      ;;
    7)
      check_old_sources
      pause
      ;;
    8)
      auto_clean_sources
      pause
      ;;
    0)
      echo -e "${GREEN}已退出，感谢使用！${NC}"
      break
      ;;
    *)
      echo -e "${RED}无效选项，请重新输入。${NC}"
      pause
      ;;
  esac
done
