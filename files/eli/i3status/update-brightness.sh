#!/bin/bash

# 定时更新所有状态信息到临时文件
while true; do
    /home/eli/.config/i3status/brightness.sh > /tmp/i3status_brightness
    /home/eli/.config/i3status/music.sh > /tmp/i3status_music
    /home/eli/.config/i3status/netspeed.sh > /tmp/i3status_netspeed
    /home/eli/.config/i3status/load.sh > /tmp/i3status_load
    sleep 2
done