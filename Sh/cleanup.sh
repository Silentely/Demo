#!/bin/bash
rm -rf /initrd.img*
rm -rf /vmlinuz*
rm -rf /lost+found/
rm -rf /boot/grub/locale/*
rm -rf /usr/lib/firmware/
rm -rf /var/lib/apt/lists/*
rm -rf /var/backups/*
apt-get clean
rm -rf /var/log/apt/*
rm -rf /var/log/sysstat/*
echo > /var/log/alternatives.log
echo > /var/log/auth.log
echo > /var/log/btmp
echo > /var/log/daemon.log
echo > /var/log/debug
echo > /var/log/dpkg.log
echo > /var/log/faillog
rm -rf /var/log/journal/
echo > /var/log/kern.log
echo > /var/log/lastlog
echo > /var/log/messages
rm -rf /var/log/private/*
rm -rf /var/log/runit/*
echo > /var/log/syslog
echo > /var/log/wtmp
echo > ~/.bash_history
rm -rf /usr/share/doc/*
rm -rf /usr/share/doc-base/*
rm -rf /usr/share/man/*
rm -rf /usr/share/groff/*
rm -rf /usr/share/info/*
rm -rf /usr/share/lintian/*
rm -rf /usr/share/linda/*
rm -rf /usr/share/common-licenses/*
rm -rf /usr/share/zsh/*
rm -rf /usr/share/icons/*
rm -rf /usr/share/pixmaps/*
rm -rf /usr/share/dict/*
rm -rf /usr/share/bug/*
rm -rf /usr/share/applications/*
rm -rf /usr/share/vim/vim82/doc/*
rm -rf /var/lib/dhcp/*
rm -rf /var/lib/dpkg/*-old
rm -rf /var/lib/ucf/cache/*
rm -rf /var/lib/ucf/hashfile.*
rm -rf /var/lib/ucf/registry.*
ls –color=never /usr/share/locale | grep -v -E ‘^locale.alias$’ | xargs -I{} rm -rf ‘/usr/share/locale/'{}
echo -n > /usr/share/locale/locale.alias
ls –color=never /usr/share/i18n/locales | grep -v -E ‘^C$|^en_GB|^en_US|^i18n|^iso14651|^POSIX$|^translit_|^zh_CN’ | xargs -I{} rm -rf ‘/usr/share/i18n/locales/'{}
