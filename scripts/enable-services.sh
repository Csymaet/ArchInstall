#!/bin/bash
# 🔒 以 root 身份运行（由 install_3_apps.sh 调用）
# 启用系统服务
# 按需增删 systemctl enable 行即可
# 仅在对应软件已安装时启用

command -v dhcpcd &>/dev/null && systemctl enable dhcpcd.service
command -v sshd &>/dev/null && systemctl enable sshd.service
command -v sddm &>/dev/null && systemctl enable sddm.service
command -v docker &>/dev/null && systemctl enable docker.service
command -v bluetoothd &>/dev/null && systemctl enable bluetooth.service
command -v v2raya &>/dev/null && systemctl enable v2raya.service
