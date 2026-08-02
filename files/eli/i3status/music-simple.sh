#!/bin/bash

# 非常简单的音乐状态脚本，避免复杂输出
status=$(playerctl status 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$status" ]; then
    echo "Music: No Player"
    exit 0
fi

# 获取播放状态
case "$status" in
    "Playing")
        icon=">"
        ;;
    "Paused")
        icon="||"
        ;;
    *)
        icon="[]"
        ;;
esac

# 获取歌曲信息，限制长度
title=$(playerctl metadata title 2>/dev/null | head -c 25)

if [ -n "$title" ]; then
    echo "Music: $icon $title"
else
    echo "Music: $icon Unknown"
fi