#!/bin/bash

# 更新VPN状态的脚本
# 定期运行，将状态写入临时文件

OUTPUT_FILE="/tmp/i3status_vpn"

while true; do
    # 获取VPN状态
    vpn_status=$(/home/eli/.config/i3status/vpn_status.sh)
    
    # 写入临时文件
    echo "$vpn_status" > "$OUTPUT_FILE"
    
    # 每30秒更新一次
    sleep 30
done