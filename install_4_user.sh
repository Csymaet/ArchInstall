#!/bin/bash

run() {
  output="/home/$(whoami)/install_log"
  url_installer=$(cat /var_url_installer)
  # dry_run=$(cat /var_dry_run)
  cd /tmp

  ## 在家目录下创建一些文件夹
  log INFO "CREATE DIRECTORIES" "$output"
  create-directories

  ## 配置应用
  log INFO "CONFIG APPS" "$output"
  config-apps
}

log() {
  local -r level=${1:?}
  local -r message=${2:?}
  local -r output=${3:?}
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

create-directories() {
  mkdir -p /home/"$(whoami)"/myfile
}

config-apps() {
  ## i3
  mkdir -p ~/.config/i3
  curl "$url_installer/files/i3/config" >~/.config/i3/config

  # 下面的步骤可能会因网络原因执行失败(那就手动执行吧)

  ## oh-my-zsh
  command -v zsh &>/dev/null && sh /usr/share/oh-my-zsh/tools/install.sh
}

run "$@"
