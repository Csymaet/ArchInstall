#!/bin/bash
set -euo pipefail

run() {
    output=$(cat /var_output)

    log INFO "FETCH VARS FROM FILES" "$output"
    name=$(cat /var_user_name)
    url_installer=$(cat /var_url_installer)
    dry_run=$(cat /var_dry_run)
    selected_apps=$(cat /var_selected_apps)

    # 添加cn仓库
    add-cn-repo
    log INFO "CN REPO ADDED" "$output"

    # 安装 yay（AUR 包需要）
    log INFO "INSTALL YAY" "$output"
    install-yay

    # 安装用户选择的软件
    log INFO "INSTALL SELECTED APPS" "$output"
    install-apps "$selected_apps"

    # 启动服务
    log INFO "ENABLE SERVICES" "$output"
    run-remote-script "enable-services.sh"

    # 配置应用
    log INFO "CONFIG APPS" "$output"
    run-remote-script "config-apps-system.sh"

    # 设置 sudo 权限
    set-user-permissions
    log INFO "USER PERMISSIONS SET" "$output"

    # 进入下一步
    continue-install "$url_installer" "$name"
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

install-yay() {
    pacman --noconfirm --needed -S yay
}

# yay 同时支持 pacman 仓库和 AUR，无需区分
# AUR 包禁止 root 构建，需临时给用户免密 sudo 后以普通用户运行 yay
install-apps() {
    local -r apps=${1:?}
    if [[ -n "$apps" ]]; then
        echo "$name ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/tmp-install
        sudo -u "$name" yay --noconfirm --needed -S $apps
        rm /etc/sudoers.d/tmp-install
    fi
}

# 从远程仓库下载配置脚本并执行
run-remote-script() {
    local -r script_name=${1:?}
    local -r tmp="/tmp/$script_name"
    curl -Lf "$url_installer/scripts/$script_name" >"$tmp"
    bash "$tmp" "$url_installer" "$name"
    rm "$tmp"
}

set-user-permissions() {
    curl -Lf "$url_installer/files/sudoers" > /etc/sudoers
}

continue-install() {
    local -r url_installer=${1:?}
    local -r name=${2:?}

    curl -Lf "$url_installer/install_4_user.sh" > /tmp/install_4_user.sh

    if [ "$dry_run" = false ]; then
        sudo -u "$name" bash /tmp/install_4_user.sh
    fi
}

run "$@"
