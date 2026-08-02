#!/bin/bash
set -euo pipefail
# 启用系统服务（网络服务已在 install_3 中启用）
# 按需增删 systemctl enable 行即可

if command -v sshd &>/dev/null; then sudo systemctl enable sshd.service; fi
if command -v sddm &>/dev/null; then sudo systemctl enable sddm.service; fi
if command -v docker &>/dev/null; then sudo systemctl enable docker.service; fi
if [[ -f /usr/lib/systemd/system/bluetooth.service ]]; then sudo systemctl enable bluetooth.service; fi
if [[ -f /usr/lib/systemd/system/runsunloginclient.service ]]; then sudo systemctl enable runsunloginclient.service; fi
if command -v postgres &>/dev/null; then sudo systemctl enable postgresql.service; fi
