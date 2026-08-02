#!/bin/bash

# 获取当前亮度百分比
current=$(brightnessctl get 2>/dev/null || echo "0")
max=$(brightnessctl max 2>/dev/null || echo "100")

if [ "$max" -ne 0 ]; then
    percentage=$((current * 100 / max))
else
    percentage=0
fi

# 根据亮度选择图标
if [ "$percentage" -ge 80 ]; then
    icon="☀"
elif [ "$percentage" -ge 60 ]; then
    icon="◐"
elif [ "$percentage" -ge 40 ]; then
    icon="◑"
elif [ "$percentage" -ge 20 ]; then
    icon="◒"
else
    icon="●"
fi

echo "Br:$percentage%"