#!/bin/bash

run() {
    output=$(cat /var_output)

    log INFO "FETCH VARS FROM FILES" "$output"
    name=$(cat /tmp/var_user_name)
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
    enable-services

    # 配置应用
    log INFO "CONFIG APPS" "$output"
    config-apps

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
install-apps() {
    local -r apps=${1:?}
    [[ -n "$apps" ]] && yay --noconfirm --needed -S $apps
}

enable-services() {
    systemctl enable dhcpcd.service
    systemctl enable sshd.service
    systemctl enable sddm.service
    # 仅在对应软件已安装时启用
    command -v docker &>/dev/null && systemctl enable docker.service
    command -v bluetoothd &>/dev/null && systemctl enable bluetooth.service
    command -v v2raya &>/dev/null && systemctl enable v2raya.service
}

config-apps() {
    # profile：登录后自动进入 ~/myfile 目录
    echo -e "\n# 进入我的目录\nif [ -d ~/myfile ]; then\n  cd ~/myfile\nfi" >> /etc/profile

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
}

set-user-permissions() {
    curl "$url_installer/files/sudoers" > /etc/sudoers
}

continue-install() {
    local -r url_installer=${1:?}
    local -r name=${2:?}

    curl "$url_installer/install_4_user.sh" > /tmp/install_4_user.sh

    if [ "$dry_run" = false ]; then
        sudo -u "$name" bash /tmp/install_4_user.sh
    fi
}

run "$@"
