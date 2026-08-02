#!/bin/bash

# 获取音乐播放器状态
status=$(playerctl status 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$status" ]; then
    echo "♪ No Player"
    exit 0
fi

# 获取播放状态图标
case "$status" in
    "Playing")
        icon=">"
        ;;
    "Paused")
        icon="||"
        ;;
    "Stopped")
        icon="[]"
        ;;
    *)
        icon="♪"
        ;;
esac

# 获取歌曲信息
artist=$(playerctl metadata artist 2>/dev/null | head -c 15)
title=$(playerctl metadata title 2>/dev/null | head -c 20)

if [ -n "$artist" ] && [ -n "$title" ]; then
    echo "$icon $artist - $title"
elif [ -n "$title" ]; then
    echo "$icon $title"
else
    echo "$icon Unknown"
fi