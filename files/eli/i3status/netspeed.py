#!/usr/bin/env python3
import time
import json

def get_network_bytes():
    with open('/proc/net/dev', 'r') as f:
        lines = f.readlines()
    
    rx_bytes = 0
    tx_bytes = 0
    
    for line in lines[2:]:  # Skip header lines
        parts = line.split()
        if parts[0].startswith('lo'):  # Skip loopback
            continue
        rx_bytes += int(parts[1])
        tx_bytes += int(parts[9])
    
    return rx_bytes, tx_bytes

def format_bytes(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val}B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val/1024:.1f}K"
    else:
        return f"{bytes_val/(1024*1024):.1f}M"

def main():
    try:
        rx1, tx1 = get_network_bytes()
        time.sleep(1)
        rx2, tx2 = get_network_bytes()
        
        rx_speed = rx2 - rx1
        tx_speed = tx2 - tx1
        
        result = {
            "full_text": f"📈 ↓{format_bytes(rx_speed)}/s ↑{format_bytes(tx_speed)}/s",
            "color": "#a3be8c"
        }
        print(json.dumps(result))
    except:
        result = {
            "full_text": "📈 N/A",
            "color": "#bf616a"
        }
        print(json.dumps(result))

if __name__ == "__main__":
    main()