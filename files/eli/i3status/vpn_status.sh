#!/bin/bash

# VPN状态检测脚本
# 通过IP归属地判断VPN连接状态

# 获取IP归属地
get_country() {
    # 尝试多个API，增加可靠性
    local country
    country=$(curl -s --connect-timeout 5 https://ipapi.co/country_name 2>/dev/null)
    if [ -z "$country" ]; then
        country=$(curl -s --connect-timeout 5 https://ipinfo.io/country 2>/dev/null)
    fi
    if [ -z "$country" ]; then
        country=$(curl -s --connect-timeout 5 https://ip.sb/country 2>/dev/null)
    fi
    echo "$country"
}

# 判断VPN状态
check_vpn_status() {
    local country=$(get_country)
    
    if [ -z "$country" ]; then
        echo "🔴 网络异常"
        return
    fi
    
    # 根据IP归属地判断VPN状态
    case "$country" in
        "China"|"CN")
            echo "🔴 直连 ($country)"
            ;;
        "United States"|"US")
            echo "🟢 VPN (US)"
            ;;
        "Japan"|"JP")
            echo "🟢 VPN (JP)"
            ;;
        "Singapore"|"SG")
            echo "🟢 VPN (SG)"
            ;;
        "Hong Kong"|"HK")
            echo "🟢 VPN (HK)"
            ;;
        *)
            echo "🟢 VPN ($country)"
            ;;
    esac
}

# 输出结果
check_vpn_status