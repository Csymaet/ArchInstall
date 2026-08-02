#!/bin/bash

# 网络速度监控脚本
INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

if [ -z "$INTERFACE" ]; then
    echo "Net: None"
    exit 0
fi

# 读取网络统计
RX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes 2>/dev/null || echo "0")
TX_BYTES=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes 2>/dev/null || echo "0")

# 读取上次的数据
CACHE_FILE="/tmp/netspeed_cache"
if [ -f "$CACHE_FILE" ]; then
    read OLD_RX OLD_TX OLD_TIME < "$CACHE_FILE"
else
    OLD_RX=$RX_BYTES
    OLD_TX=$TX_BYTES
    OLD_TIME=$(date +%s)
fi

# 当前时间
CURRENT_TIME=$(date +%s)
TIME_DIFF=$((CURRENT_TIME - OLD_TIME))

if [ $TIME_DIFF -le 0 ]; then
    TIME_DIFF=1
fi

# 计算速度 (字节/秒)
RX_SPEED=$(((RX_BYTES - OLD_RX) / TIME_DIFF))
TX_SPEED=$(((TX_BYTES - OLD_TX) / TIME_DIFF))

# 转换为人类可读格式
format_speed() {
    local speed=$1
    if [ $speed -gt 1048576 ]; then
        echo "$((speed / 1048576))M"
    elif [ $speed -gt 1024 ]; then
        echo "$((speed / 1024))K"
    else
        echo "${speed}B"
    fi
}

DOWN=$(format_speed $RX_SPEED)
UP=$(format_speed $TX_SPEED)

echo "↓${DOWN} ↑${UP}"

# 保存当前数据
echo "$RX_BYTES $TX_BYTES $CURRENT_TIME" > "$CACHE_FILE"