#!/bin/bash
set -euo pipefail

output=$(cat /var_output)

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

# 在家目录下创建文件夹
log INFO "CREATE DIRECTORIES" "$output"
mkdir -p ~/myfile
