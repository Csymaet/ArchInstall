#!/bin/bash
set -euo pipefail
# 以普通用户身份运行，需要 root 权限的操作使用 sudo
# 参数：$1=远程仓库地址

url_installer=${1:?}
name=$(whoami)

# sddm 登录管理器配置
if command -v sddm &>/dev/null; then
    sudo mkdir -p /etc/sddm.conf.d
    curl -Lf "$url_installer/files/sddm.conf" | sudo tee /etc/sddm.conf.d/sddm.conf >/dev/null
fi

# docker：将用户加入 docker 组
if command -v docker &>/dev/null; then sudo gpasswd -a "$name" docker; fi

# zsh 设为默认 shell
if command -v zsh &>/dev/null; then sudo chsh -s /bin/zsh "$name"; fi

# i3 窗口管理器配置
mkdir -p ~/.config/i3
curl -Lf "$url_installer/files/i3/config" > ~/.config/i3/config

# oh-my-zsh
if command -v zsh &>/dev/null; then sh /usr/share/oh-my-zsh/tools/install.sh; fi
