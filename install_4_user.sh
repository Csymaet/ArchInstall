#!/bin/bash

run() {
  output="/home/$(whoami)/install_log"
  url_installer=$(cat /var_url_installer)
  # dry_run=$(cat /var_dry_run)
  cd /tmp

  ## 在家目录下创建一些文件夹
  log INFO "CREATE DIRECTORIES" "$output"
  run-remote-script "create-directories.sh"

  ## 配置应用
  log INFO "CONFIG APPS" "$output"
  run-remote-script "config-apps-user.sh"
}

log() {
  local -r level=${1:?}
  local -r message=${2:?}
  local -r output=${3:?}
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

run-remote-script() {
  local -r script_name=${1:?}
  local -r tmp="/tmp/$script_name"
  curl "$url_installer/scripts/$script_name" >"$tmp"
  bash "$tmp" "$url_installer"
  rm "$tmp"
}

run "$@"
