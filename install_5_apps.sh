#!/bin/bash
set -euo pipefail

# 进入系统后手动执行：装软件 + 启用服务 + 配置应用
# 用法：bash install_5_apps.sh [远程仓库地址]
#       不传参时自动读取 ~/install_url

url_installer=${1:-$(cat ~/install_url 2>/dev/null)}
if [[ -z "$url_installer" ]]; then
    echo "用法: bash install_5_apps.sh <url_installer>"
    exit 1
fi
name=$(whoami)
output="/tmp/install_5.log"

run() {
    log INFO "START INSTALL 5" "$output"

    install-selected-apps
    log INFO "APPS INSTALLED" "$output"

    run-remote-script "enable-services.sh"
    log INFO "SERVICES ENABLED" "$output"

    run-remote-script "config-apps.sh"
    log INFO "CONFIG DONE" "$output"

    log INFO "ALL DONE" "$output"
    echo "✅ 安装完成！日志: $output"
}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

install-selected-apps() {
    local apps=""
    if [[ -f ~/install_selected_apps ]]; then
        apps=$(cat ~/install_selected_apps)
    fi
    if [[ -n "$apps" ]]; then
        yay --noconfirm --needed -S $apps
    fi
}

run-remote-script() {
    local -r script_name=${1:?}
    local -r tmp="/tmp/$script_name"
    curl -Lf "$url_installer/scripts/$script_name" >"$tmp"
    bash "$tmp" "$url_installer"
    rm "$tmp"
}

run "$@"
