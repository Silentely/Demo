#!/bin/bash
v4=$(echo $*|grep -ipv4)
if [[ "$OSTYPE" == "linux-gnu" ]]; then
    if [ -f /etc/redhat-release ]; then
        cmd=yum
        wireguard=wireguard-tools
        $cmd -y install epel-release
        #$cmd makecache
    elif [ -f /etc/debian_version ]; then
        cmd=apt-get
        wireguard=wireguard
        if [ "$(cat /etc/apt/sources.list|grep debian)" ]; then
            echo "deb http://deb.debian.org/debian/ unstable main" > /etc/apt/sources.list.d/unstable.list
            printf 'Package: *\nPin: release a=unstable\nPin-Priority: 150\n' > /etc/apt/preferences.d/limit-unstable
        fi
        $cmd update
    fi
else
    echo -e "暂仅支持 Linux(CentOS/Ubuntu/Debian) 系统"
fi

$cmd install -y wget $wireguard
# wireguard-go
wget https://git.haoduck.cf/github.com/peng4740/wireguard-go-builder/releases/download/0.0.20201118/wireguard-go-linux-amd64.tar.gz
tar zxf wireguard-go-linux-amd64.tar.gz
mv wireguard-go /usr/local/sbin
rm -f wireguard-go-linux-amd64.tar.gz
# wgcf
wget https://git.haoduck.cf/github.com/ViRb3/wgcf/releases/download/v2.2.2/wgcf_2.2.2_linux_amd64 -O /usr/local/sbin/wgcf
chmod +x /usr/local/sbin/wgcf
echo|wgcf register
wgcf generate
if [ "$v4" ]; then
    sed -i '/0\.0\.0\.0\/0/d' wgcf-profile.conf
else
    sed -i '/\:\:\/0/d' wgcf-profile.conf
fi
mkdir -p /etc/wireguard
cp -f wgcf-profile.conf /etc/wireguard/wgcf.conf
# systemctl
ln -s /usr/bin/resolvectl /usr/local/bin/resolvconf
ln -sf /lib/systemd/system/systemd-resolved.service /etc/systemd/system/dbus-org.freedesktop.resolve1.service
systemctl enable wg-quick@wgcf
systemctl start wg-quick@wgcf
echo -e "完成了，可以 ping 1.1.1.1 试试看了\n如果没出问题，这里应该能显示你的IP：$(wget -qO- ipv4.ip.sb) <=如果这里是空的，大概是失败了"
