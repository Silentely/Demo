#!/bin/bash
#删除snap旧版本
#在运行此之前关闭所有snap
 set -eu
 LANG=en_US.UTF-8 snap list --all | awk '/disabled/{print $1, $3}' |
     while read snapname revision; do
         snap remove "$snapname" --revision="$revision"
     done
