#!/bin/bash

# 获取系统负载
LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | xargs)
TEMP=""

# 尝试获取CPU温度
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
    TEMP_RAW=$(cat /sys/class/thermal/thermal_zone0/temp)
    TEMP_C=$((TEMP_RAW / 1000))
    TEMP=" ${TEMP_C}°C"
fi

# 获取内存使用率
MEM_INFO=$(free | grep '^Mem:')
MEM_TOTAL=$(echo $MEM_INFO | awk '{print $2}')
MEM_USED=$(echo $MEM_INFO | awk '{print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

echo "Load:${LOAD}${TEMP} Mem:${MEM_PERCENT}%"