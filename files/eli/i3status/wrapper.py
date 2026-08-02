#!/usr/bin/env python3

import sys
import json
import subprocess
import time

def get_music_status():
    """获取音乐状态"""
    try:
        result = subprocess.run(['/home/eli/.config/i3status/music-simple.sh'], 
                              capture_output=True, text=True, timeout=2)
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            return "Music: No Player"
    except Exception:
        return "Music: Error"

def print_line(message):
    """向 i3bar 输出一行"""
    sys.stdout.write(message + '\n')
    sys.stdout.flush()

def read_line():
    """从 i3status 读取一行"""
    try:
        line = sys.stdin.readline()
        return line.strip()
    except KeyboardInterrupt:
        sys.exit()

if __name__ == '__main__':
    # 打印头部信息
    print_line(read_line())
    print_line(read_line())

    while True:
        try:
            line = read_line()
            if line.startswith('['):
                # 解析 JSON
                try:
                    j = json.loads(line[1:] if line.startswith('[,') else line)
                    
                    # 添加音乐状态到开头
                    music_status = get_music_status()
                    music_item = {
                        'full_text': music_status,
                        'name': 'music',
                        'color': '#FFFFFF'
                    }
                    
                    # 插入到数组开头
                    j.insert(0, music_item)
                    
                    # 输出修改后的 JSON
                    print_line(',[' + json.dumps(j)[1:])
                except json.JSONDecodeError:
                    print_line(line)
            else:
                print_line(line)
        except Exception:
            break