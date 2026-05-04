#!/bin/bash
set -euo pipefail

run() {
    output=$(cat /var_output)

    log INFO "FETCH VARS FROM FILES" "$output"
    name=$(cat /var_user_name)
    url_installer=$(cat /var_url_installer)
    dry_run=$(cat /var_dry_run)

    # 添加cn仓库
    add-cn-repo
    log INFO "CN REPO ADDED" "$output"

    # 安装 yay（AUR 包需要）
    log INFO "INSTALL YAY" "$output"
    pacman --noconfirm --needed -S yay

    # 安装必装软件（v2raya）
    log INFO "INSTALL REQUIRED APPS" "$output"
    pacman --noconfirm --needed -S v2ray v2raya
    REDACTED
    REDACTED
    REDACTED
    REDACTED
    systemctl enable v2raya.service

    # 启用网络服务（重启后必须有网络才能继续安装）
    log INFO "ENABLE NETWORK SERVICES" "$output"
    systemctl enable iwd.service
    systemctl enable dhcpcd.service

    # 设置 sudo 权限
    log INFO "SET USER PERMISSIONS" "$output"
    curl -Lf "$url_installer/files/sudoers" > /etc/sudoers

    # 保存用户选择的软件列表（供 install_5 使用）
    local selected_apps
    selected_apps=$(cat /var_selected_apps)
    echo "$selected_apps" > "/home/$name/selected_apps.txt"
    chown "$name" "/home/$name/selected_apps.txt"

    # 进入下一步
    curl -Lf "$url_installer/install_4_user.sh" > /tmp/install_4_user.sh
    if [ "$dry_run" = false ]; then
        sudo -u "$name" bash /tmp/install_4_user.sh
    fi
}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

add-cn-repo() {
    echo "[archlinuxcn]" >> /etc/pacman.conf && echo "Server = https://mirrors.cloud.tencent.com/archlinuxcn/\$arch" >> /etc/pacman.conf
    pacman -Sy && pacman --noconfirm --needed -S archlinuxcn-keyring
}

run "$@"
