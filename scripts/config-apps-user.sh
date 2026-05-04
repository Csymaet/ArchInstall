#!/bin/bash
# 👤 以普通用户身份运行（由 install_4_user.sh 调用）
# 参数：$1=远程仓库地址

url_installer=${1:?}

# i3 窗口管理器配置
mkdir -p ~/.config/i3
curl "$url_installer/files/i3/config" >~/.config/i3/config

# 下面两步可能会因网络原因执行失败(那就手动执行吧~)

# oh-my-zsh
command -v zsh &>/dev/null && sh /usr/share/oh-my-zsh/tools/install.sh
