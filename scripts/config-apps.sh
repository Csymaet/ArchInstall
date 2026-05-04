#!/bin/bash
# 应用配置
# 按需增删配置块即可
# 可用变量：$name（用户名）、$url_installer（远程仓库地址）

# sddm 登录管理器配置
command -v sddm &>/dev/null && {
    mkdir -p /etc/sddm.conf.d
    curl "$url_installer/files/sddm.conf" > /etc/sddm.conf.d/sddm.conf
}

# docker：将用户加入 docker 组
command -v docker &>/dev/null && gpasswd -a "$name" docker

# v2raya 配置
command -v v2raya &>/dev/null && {
    REDACTED
    curl "$url_installer/files/REDACTED" > /etc/REDACTED
    curl "$url_installer/files/REDACTED" > /etc/REDACTED
    curl "$url_installer/files/REDACTED" > /etc/REDACTED
}

# zsh 设为默认 shell
command -v zsh &>/dev/null && chsh -s /bin/zsh "$name"
