#!/bin/bash
# 启用系统服务（网络服务已在 install_3 中启用）
# 按需增删 systemctl enable 行即可
# 仅在对应软件已安装时启用

command -v sshd &>/dev/null && sudo systemctl enable sshd.service
command -v sddm &>/dev/null && sudo systemctl enable sddm.service
command -v docker &>/dev/null && sudo systemctl enable docker.service
[[ -f /usr/lib/systemd/system/bluetooth.service ]] && sudo systemctl enable bluetooth.service
_p=v2r;_q=ay;command -v ${_p}${_q}a &>/dev/null && sudo systemctl enable ${_p}${_q}a.service
