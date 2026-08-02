#!/bin/bash
set -euo pipefail
# 以普通用户身份运行，需要 root 权限的操作使用 sudo
# 参数：$1=远程仓库地址

url_installer=${1:?}
name=$(whoami)

# 从 configs.toml 驱动部署配置文件
curl -Lf "$url_installer/tools/config-manager/configs.toml" > /tmp/configs.toml
curl -Lf "$url_installer/tools/config-manager/deploy.py" > /tmp/deploy.py
python /tmp/deploy.py /tmp/configs.toml "$url_installer" --stage config

# docker：将用户加入 docker 组
if command -v docker &>/dev/null; then sudo gpasswd -a "$name" docker; fi

# zsh 设为默认 shell
if command -v zsh &>/dev/null; then sudo chsh -s /bin/zsh "$name"; fi

# oh-my-zsh
if command -v zsh &>/dev/null; then sh /usr/share/oh-my-zsh/tools/install.sh; fi

# openclaw：初始化守护进程
if command -v openclaw &>/dev/null; then openclaw onboard --install-daemon; fi
