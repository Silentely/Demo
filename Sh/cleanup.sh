#!/bin/bash

# 系统垃圾清理函数
clean_system() {
  echo "正在清理系统垃圾文件..."
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
  echo "系统垃圾文件清理完成!"
}

# Docker垃圾清理函数
clean_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "正在清理无用的Docker镜像、容器、网络和卷..."
    docker system prune -af --volumes
    echo "Docker垃圾已清理完成!"
  else
    echo "未检测到docker命令，跳过Docker清理。"
  fi
}

# 旧内核清理函数
clean_kernel() {
  echo "正在清理旧的系统内核..."
  CURRENT_KERNEL=$(uname -r)
  if command -v dpkg >/dev/null 2>&1; then
    dpkg -l | awk '/linux-image-[0-9]/{print $2}' | grep -v "$CURRENT_KERNEL" | xargs apt-get -y purge
    dpkg -l | awk '/linux-headers-[0-9]/{print $2}' | grep -v "$CURRENT_KERNEL" | xargs apt-get -y purge
  elif command -v rpm >/dev/null 2>&1; then
    rpm -q kernel | grep -v "$CURRENT_KERNEL" | xargs -r yum -y remove
  else
    echo "未知的包管理器，无法自动清理旧内核。"
  fi
  echo "旧内核清理完成!"
}

while true; do
  echo "请选择清理操作："
  echo "1) 一键清理（系统+Docker+旧内核）"
  echo "2) 仅清理Docker无用镜像/容器"
  echo "3) 仅清理旧内核"
  echo "4) 仅清理系统垃圾文件"
  echo "0) 退出"
  read -rp "请输入选项(0-4): " choice
  case $choice in
    1)
      clean_system
      clean_docker
      clean_kernel
      ;;
    2)
      clean_docker
      ;;
    3)
      clean_kernel
      ;;
    4)
      clean_system
      ;;
    0)
      echo "已退出。"
      break
      ;;
    *)
      echo "无效选项，请重新输入。"
      ;;
  esac
  echo
done
