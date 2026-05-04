#!/bin/bash

# ============================================================================
# Arch Linux 自动安装脚本 — 第一阶段（在 Live USB 环境中运行）
# ============================================================================
# 本脚本在 Arch Live USB 启动后执行，负责：
#   1. 配置镜像源和时钟
#   2. 交互式选择磁盘、设置主机名
#   3. 分区、格式化、挂载
#   4. pacstrap 安装基础系统
#   5. arch-chroot 进入新系统执行第二阶段脚本
#
# 用法：bash install_1_sys.sh [-d true|false] [-o /path/to/log]
#   -d  是否干跑模式（只打印日志，不执行破坏性操作），默认 false
#   -o  日志输出文件路径，默认 /dev/tty2（第二个虚拟终端）
# ============================================================================

# 安全选项：
#   -e  遇到错误立即退出（防止在错误状态下继续执行）
#   -u  使用未定义变量时报错（防止拼写错误）
#   -o pipefail  管道中任一命令失败则整个管道失败
set -euo pipefail

trap 'echo "❌ 脚本在第 $LINENO 行出错，退出码: $?" > /tmp/install_crash.log' ERR

# ----------------------------------------------------------------------------
# 📡 安装脚本的远程仓库地址
# ----------------------------------------------------------------------------
# ⚠️ 如果你是 Fork 的仓库，必须修改这里的 URL 为你自己的地址
# url-installer: 用于下载单个脚本文件（raw 文件地址）
# repo-installer: 用于 git clone 整个仓库
url-installer() {
  echo "https://gitee.com/unityw/ArchInstall/raw/master"
}

repo-installer() {
  echo "https://gitee.com/unityw/ArchInstall.git"
}

# ============================================================================
# 🚀 主流程入口
# ============================================================================
run() {
  # ==========================================================================
  # ① 解析命令行参数
  # ==========================================================================
  # -d  干跑模式开关（true = 只打印日志，跳过所有破坏性操作）
  # -o  日志输出目标（默认 /dev/tty2，即第二个虚拟终端）
  #     用户在 tty1 操作，日志输出到 tty2，互不干扰
  #     可通过 Ctrl+Alt+F2 切换到 tty2 查看日志
  local dry_run=${dry_run:-false}
  local output=${output:-/dev/tty2}

  # getopts 解析选项：d: 和 o: 后面的冒号表示该选项需要一个参数
  # OPTARG 是 getopts 内置变量，保存当前选项的参数值
  while getopts d:o: option; do
    case "${option}" in
    d) dry_run=${OPTARG} ;; # 例如：-d true
    o) output=${OPTARG} ;;  # 例如：-o /tmp/install.log
    *) ;;                   # 忽略未知选项
    esac
  done

  log INFO "DRY RUN? $dry_run" "$output"

  if [[ -f /tmp/install_crash.log ]]; then
    dialog --title "上次运行出错" --msgbox "$(cat /tmp/install_crash.log)" 10 50
    rm /tmp/install_crash.log
    kill "$PPID" 2>/dev/null
    exit 1
  fi

  # ==========================================================================
  # ② 配置 pacman 镜像源
  # ==========================================================================
  # 在 /etc/pacman.d/mirrorlist 头部插入国内镜像源（中科大 + 清华）
  # 插入头部 = 最高优先级，pacman 会优先使用这两个源下载包
  log INFO "SELECT MIRROR SOURCE" "$output"
  select-mirror-source

  # ==========================================================================
  # ③ 同步系统时钟
  # ==========================================================================
  # 启用 NTP 网络时间同步，确保系统时钟准确
  # ⚠️ 必须准确：pacman 下载包时需要验证 TLS 证书，时钟偏差会导致失败
  log INFO "SET TIME" "$output"
  set-timedate

  # ==========================================================================
  # ④ 安装 dialog 工具
  # ==========================================================================
  install-dialog

  # ==========================================================================
  # ⑤ 设置中文终端环境（kmscon）
  # ==========================================================================
  # Linux 内核 TTY 不支持中文（512 字形硬限制）
  # 通过 kmscon（用户空间终端）绕过，支持完整 UTF-8 / CJK
  # 首次运行：安装 → 配置 → 自动 re-exec 进入 kmscon
  if [[ -z "${IN_KMSCON:-}" ]]; then
    dialog --msgbox "Chinese terminal will be installed.\n\nAfter installation, the script will restart automatically." 10 50
    setup-chinese-terminal
    exec kmscon --no-reset-env --login -- /bin/bash "$0"
  fi

  # ==========================================================================
  # ⑥ 安全确认
  # ==========================================================================
  # 弹出确认对话框，默认选中"否"（--defaultno）
  # 提示用户此操作会销毁磁盘数据，选"否"则直接 exit 退出脚本
  # 🛡️ 这是安全阀门，防止误操作
  dialog-are-you-sure

  # ==========================================================================
  # ⑦ 设置 root 密码
  # ==========================================================================
  local root_pass
  dialog-input-password rp "请设置 root 用户密码"
  root_pass=$(cat rp) && rm rp
  log INFO "ROOT PASSWORD SET" "$output"

  # ==========================================================================
  # ⑧ 设置主机名和用户密码
  # ==========================================================================
  local hostname
  dialog-name-of-computer hn
  hostname=$(cat hn) && rm hn
  log INFO "HOSTNAME: $hostname" "$output"

  local user_pass
  dialog-input-password up "请设置用户 $hostname 的密码"
  user_pass=$(cat up) && rm up
  log INFO "USER PASSWORD SET" "$output"

  # ==========================================================================
  # ⑨ 选择目标磁盘
  # ==========================================================================
  # 用 dialog --radiolist 列出所有可用磁盘，用户用空格选择、回车确认
  # 选择结果写入临时文件 hd，读取后立即删除（保持干净）
  local disk
  dialog-what-disk-to-use hd
  disk=$(cat hd) && rm hd
  log INFO "DISK CHOSEN: $disk" "$output"

  # ==========================================================================
  # ⑩ Swap 文件大小
  # ==========================================================================
  # 弹框让用户输入 swap 文件大小（GB），默认 8G
  local swap_size
  dialog-what-swap-size swaps
  swap_size=$(cat swaps) && rm swaps
  log INFO "SWAP SIZE: ${swap_size}G" "$output"

  # ==========================================================================
  # ⑪ 选择要安装的软件
  # ==========================================================================
  # 从远程仓库下载 CSV 文件，弹出 checklist 让用户选择
  # 必装的不会显示（第一阶段已装），默认的预选中，可选的手动勾选
  local apps_dir="/tmp/apps"
  log INFO "DOWNLOAD APPS CSV" "$output"
  download-apps-csv "$(repo-installer)" "$apps_dir"

  local selected_apps
  dialog-choose-apps selapps "$apps_dir"
  selected_apps=$(cat selapps | tr '\n' ' ') && rm selapps
  log INFO "SELECTED APPS: $selected_apps" "$output"

  # ==========================================================================
  # ⑫ 选择格盘方式（已禁用，当前使用更快的 wipefs 替代）
  # ==========================================================================
  # 原始设计提供三种选择：
  #   1) dd 全盘覆写零（慢但彻底）
  #   2) shred 安全擦除（更慢更安全）
  #   3) 跳过（磁盘已空）
  # local wiper
  # dialog-how-wipe-disk "$disk" dfile
  # wiper=$(cat dfile) && rm dfile
  # log INFO "WIPER CHOICE: $wiper" "$output"

  # ==========================================================================
  # ⑬ 使用 dd/shred 格盘（已禁用）
  # ==========================================================================
  # [[ "$dry_run" = false ]] \
  #     && log INFO "ERASE DISK" "$output" \
  #     && erase-disk "$wiper" "$disk"

  # ==========================================================================
  # ⑭ 擦除文件系统签名
  # ==========================================================================
  # 使用 wipefs 擦除磁盘上所有分区的文件系统签名
  # 比 dd/shred 快得多（只擦签名，不覆写数据），效果等同"清除分区表"
  # 内部会倒序擦除（sda2→sda1），避免分区表变化导致设备节点消失
  [[ "$dry_run" = false ]] &&
    log INFO "WIPE FILESYSTEM SIGNATURES" "$output" &&
    wipe-fs "$disk"

  # ==========================================================================
  # ⑮ 创建 GPT 分区表和分区
  # ==========================================================================
  # 分区方案（共 2 个分区，无 Swap）：
  #   分区1：512M — Boot 分区（EFI System Partition 或 BIOS Boot Partition）
  #   分区2：剩余  — Root 根分区
  #
  # 调用链：
  #   is-uefi()           → 检测是否 UEFI 启动，返回 1(UEFI) 或 0(BIOS)
  #   boot-partition()    → 根据启动模式返回 fdisk 分区类型 ID
  #                          UEFI → 1 (EFI System Partition)
  #                          BIOS → 4 (BIOS Boot Partition)
  #   fdisk-partition()   → 用 fdisk 创建 GPT 分区表和分区
  #
  # 🔒 dry_run 模式下跳过此步骤
  [[ "$dry_run" = false ]] &&
    log INFO "CREATE PARTITIONS" "$output" &&
    fdisk-partition "$disk" "$(boot-partition "$(is-uefi)")" # "$swap_size"

  # ==========================================================================
  # ⑯ 格式化分区并挂载
  # ==========================================================================
  # Root 分区：格式化为 ext4
  # Boot 分区：
  #   UEFI 模式 → 格式化为 FAT32（EFI 标准要求），挂载到 /mnt/boot/efi
  #   BIOS 模式 → 不需要单独格式化（由 GRUB 直接处理）
  #
  # ⚠️ NVMe 磁盘特殊处理：分区名带 'p' 前缀（nvme0n1p1 vs sda1）
  #
  # 🔒 dry_run 模式下跳过此步骤
  [[ "$dry_run" = false ]] &&
    log INFO "FORMAT PARTITIONS" "$output" &&
    format-partitions "$disk" "$(is-uefi)"

  # ==========================================================================
  # ⑰ 保存状态文件到 /mnt/（跨 chroot 传递变量）
  # ==========================================================================
  # arch-chroot 进入新系统后，当前 shell 的所有变量都会丢失
  # 所以必须把关键变量写入文件，第二阶段脚本从文件中读取
  #
  # 保存的变量：
  #   var_uefi          — 启动模式（0=BIOS, 1=UEFI）
  #   var_disk          — 目标磁盘设备路径（如 /dev/nvme0n1）
  #   var_hostname      — 主机名
  #   var_output        — 日志输出目标
  #   var_dry_run       — 干跑模式开关
  #   var_url_installer — 远程脚本仓库地址
  #   var_swap_size     — Swap 文件大小（GB）
  #   var_root_pass     — root 用户密码
  #   var_user_pass     — 普通用户密码
  #   var_selected_apps — 用户选择安装的软件列表（空格分隔）
  log INFO "CREATE VAR FILES" "$output"
  echo "$(is-uefi)" >/mnt/var_uefi
  echo "$disk" >/mnt/var_disk
  echo "$hostname" >/mnt/var_hostname
  echo "$output" >/mnt/var_output
  echo "$dry_run" >/mnt/var_dry_run
  url-installer >/mnt/var_url_installer
  echo "$swap_size" >/mnt/var_swap_size
  echo "$root_pass" >/mnt/var_root_pass
  echo "$user_pass" >/mnt/var_user_pass
  echo "$selected_apps" >/mnt/var_selected_apps

  # ==========================================================================
  # ⑱ 使用 pacstrap 安装基础系统
  # ==========================================================================
  # pacstrap 是 Arch 专用的系统安装工具，会在 /mnt 下安装完整的根文件系统
  # 安装的包包括：
  #   🏗️ 基础系统：base linux base-devel linux-firmware man-db
  #   🔧 引导加载：grub efibootmgr
  #   🌐 网络工具：iwd（WiFi）dhcpcd（有线）openssh（SSH服务）
  #   💻 开发工具：git neovim
  #   🔊 音频：pulseaudio pulseaudio-bluetooth
  #   📶 蓝牙：bluez-utils bluez
  #   🇨🇳 中文支持：wqy-zenhei（字体）fcitx5-im fcitx5-chinese-addons（输入法）
  #   🖥️ 窗口管理：i3 dmenu xorg-server tmux
  #   📟 终端：konsole yakuake
  #   🌍 浏览器：firefox
  #   📂 文件管理：tree ranger imlib2
  #   🛠️ 其他：flameshot（截图）termdown（倒计时）docker ntfs-3g
  #
  # 安装完成后用 genfstab 生成 /etc/fstab（文件系统挂载表）
  # 使用 -U 选项以 UUID 标识分区（比设备名更稳定，不会因插拔顺序变化）
  #
  # 🔒 dry_run 模式下跳过此步骤
  [[ "$dry_run" = false ]] &&
    log INFO "BEGIN INSTALL ARCH LINUX" "$output" &&
    install-arch-linux

  # ==========================================================================
  # ⑲ 执行第二阶段脚本（chroot 进入新系统）
  # ==========================================================================
  # 两阶段安装模式：
  #   第一阶段（当前脚本）— 在 Live USB 环境中运行，负责分区和安装包
  #   第二阶段（install_2_chroot.sh）— 在新系统环境中运行，负责：
  #     - 设置时区、locale
  #     - 配置网络
  #     - 安装 GRUB 引导
  #     - 创建用户
  #
  # 流程：
  #   1. curl 从远程仓库下载 install_2_chroot.sh 到 /mnt/
  #   2. arch-chroot /mnt 切换根目录到新系统
  #   3. 在新系统环境中执行 install_2_chroot.sh
  #
  # 💡 远程下载 = 脚本热更新，修改仓库后无需重新制作 ISO
  #
  # 🔒 dry_run 模式下跳过此步骤
  [[ "$dry_run" = false ]] &&
    log INFO "BEGIN CHROOT SCRIPT" "$output" &&
    install-chroot "$(url-installer)"

  # ==========================================================================
  # ⑳ 清理与完成
  # ==========================================================================
  # 删除之前保存的临时变量文件（var_uefi 等）
  clean

  # 弹出最终对话框：
  #   告知安装完成，询问是否重启
  #   选"是" → reboot 重启进入新系统
  #   选"否" → 清屏，留在 Live USB 环境
  end-of-install
}

# ============================================================================
# 📝 工具函数
# ============================================================================

# ----------------------------------------------------------------------------
# log — 带时间戳的日志函数
# ----------------------------------------------------------------------------
# 参数：
#   $1  日志级别（INFO / WARN / ERROR）
#   $2  日志消息
#   $3  输出目标（文件路径，如 /dev/tty2 或 /tmp/install.log）
# 输出格式：2025-01-01 12:00:00 [INFO] 消息内容
# 注意：使用 >> 追加写入，不会覆盖已有日志
log() {
  local -r level=${1:?} # -r 表示只读，:? 表示必填
  local -r message=${2:?}
  local -r output=${3:?}
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

# ----------------------------------------------------------------------------
# setup-chinese-terminal — 安装 kmscon + 中文字体，自动 re-exec 进入 kmscon
# ----------------------------------------------------------------------------
# Linux 内核 TTY 最多 512 字形，无法显示中文
# kmscon 是用户空间终端，通过 Pango 渲染完整 UTF-8 / CJK
# 首次运行：安装 → 配置 → re-exec（IN_KMSCON=1 防止循环）
# 第二次运行：跳过本函数，继续正常流程
setup-chinese-terminal() {
  pacman --noconfirm --needed -S kmscon pango wqy-microhei

  echo "zh_CN.UTF-8 UTF-8" >>/etc/locale.gen
  locale-gen

  mkdir -p /etc/kmscon
  cat >/etc/kmscon/kmscon.conf <<EOF
font-name=WenQuanYi Micro Hei Mono
font-size=14
EOF

  echo "LANG=zh_CN.UTF-8" >/etc/locale.conf
  export IN_KMSCON=1
  export LANG=zh_CN.UTF-8
}

# ----------------------------------------------------------------------------
# install-dialog — 安装 dialog（TUI 对话框工具）
# ----------------------------------------------------------------------------
# Arch Live USB 默认不带 dialog，但后续所有交互都依赖它
# -Sy        同步包数据库（从镜像源获取最新的包列表）
# --noconfirm 跳过确认提示
# -S dialog  安装 dialog 包
install-dialog() {
  pacman -Sy
  pacman --noconfirm -S dialog
}

# ----------------------------------------------------------------------------
# dialog-are-you-sure — 安全确认对话框
# ----------------------------------------------------------------------------
# --defaultno  默认光标在"否"上（防止用户习惯性按回车）
# 选"否" → exit 退出整个脚本
# 🛡️ 这是最后的安全阀门，防止用户在不知情的情况下格式化磁盘
dialog-are-you-sure() {
  dialog --defaultno \
    --title "确认" \
    --yesno "这是个人使用的 Arch Linux 自动安装脚本。\n\n\
        它会摧毁你选择的硬盘上的所有数据！\n\n\
        如果你不确定自己在做什么，请不要点"是"！\n\n\
        确定要继续吗？" 15 60 || { kill "$PPID"; exit 1; }
}

# ----------------------------------------------------------------------------
# dialog-name-of-computer — 输入主机名的对话框
# ----------------------------------------------------------------------------
# --no-cancel 不显示取消按钮
# --inputbox  文本输入框
# 2>"$file"   将用户输入重定向到文件（dialog 的标准输出是终端，stderr 是结果）
dialog-name-of-computer() {
  local file=${1:?}
  dialog --no-cancel --inputbox "请输入主机名（将同时作为用户名）。" 10 60 2>"$file"
}

# ----------------------------------------------------------------------------
# dialog-input-password — 密码输入对话框（带二次确认）
# ----------------------------------------------------------------------------
# 两次输入不一致则循环，直到一致为止
# --passwordbox 隐藏输入（显示为星号）
dialog-input-password() {
  local file=${1:?}
  local prompt=${2:?}
  local pass1=""
  local pass2=""

  while true; do
    dialog --no-cancel --passwordbox "$prompt" 10 60 2>/tmp/.pass1
    dialog --no-cancel --passwordbox "确认：请再次输入密码" 10 60 2>/tmp/.pass2
    pass1=$(cat /tmp/.pass1)
    pass2=$(cat /tmp/.pass2)
    rm /tmp/.pass1 /tmp/.pass2

    [[ "$pass1" == "$pass2" ]] && break
    dialog --msgbox "两次密码不一致，请重新输入。" 10 40
  done

  echo "$pass1" >"$file"
}

# ----------------------------------------------------------------------------
# download-apps-csv — 从远程仓库克隆 apps 目录
# ----------------------------------------------------------------------------
# git clone --depth 1 浅克隆整个仓库，然后只取 apps/ 目录
# 不硬编码 CSV 文件名，新增/删除 CSV 时自动适配
download-apps-csv() {
  local -r repo_url=${1:?}
  local -r dest=${2:?}

  pacman --noconfirm --needed -S git
  git clone --depth 1 "$repo_url" /tmp/archinstall-repo
  cp -r /tmp/archinstall-repo/apps "$dest"
  rm -rf /tmp/archinstall-repo
}

# ----------------------------------------------------------------------------
# dialog-choose-apps — 软件选择对话框
# ----------------------------------------------------------------------------
# 分两步：
#   1. --msgbox 展示必装软件列表（仅查看）
#   2. --checklist 让用户选择默认/可选软件
# 结果（空格分隔的包名列表）写入 $file
dialog-choose-apps() {
  local file=${1:?}
  local -r apps_dir=${2:?}

  # 第一步：展示必装软件
  local required_list=""
  for csv_file in "$apps_dir"/*.csv; do
    while IFS=, read -r pkg desc priority; do
      [[ "$priority" == "必装" ]] && required_list="$required_list\n  * $pkg — $desc"
    done <"$csv_file"
  done

  if [[ -n "$required_list" ]]; then
    dialog --title "必装软件（自动安装）" \
      --msgbox "以下软件将自动安装，无需选择：$required_list" 20 60
  fi

  # 第二步：选择默认/可选软件
  local checklist=()
  for csv_file in "$apps_dir"/*.csv; do
    while IFS=, read -r pkg desc priority; do
      [[ "$priority" == "必装" ]] && continue
      local status="off"
      [[ "$priority" == "默认" ]] && status="on"
      checklist+=("$pkg" "$desc" "$status")
    done <"$csv_file"
  done

  dialog --separate-output --checklist "选择要安装的软件（空格选择，回车确认）" 0 0 0 "${checklist[@]}" 2>"$file"
}

# ----------------------------------------------------------------------------
# is-uefi — 检测当前启动模式
# ----------------------------------------------------------------------------
# 返回值：
#   1 = UEFI 模式（/sys/firmware/efi/efivars 目录存在）
#   0 = BIOS/Legacy 模式（该目录不存在）
#
# 💡 这是 Arch Wiki 推荐的检测方法：
#   UEFI 固件会在 /sys/firmware/efi/ 下暴露 EFI 变量
#   BIOS 模式下这个目录根本不存在
is-uefi() {
  local uefi=0
  ls /sys/firmware/efi/efivars &>/dev/null && uefi=1

  echo "$uefi"
}

# ----------------------------------------------------------------------------
# dialog-what-disk-to-use — 选择目标磁盘的对话框
# ----------------------------------------------------------------------------
# 流程：
#   1. lsblk -d 列出所有块设备（不含分区）
#   2. awk 提取设备名和大小，拼接为 dialog 需要的格式："/dev/sda 500G on"
#   3. grep 过滤出真实磁盘（排除 loop、rom 等虚拟设备）
#   4. dialog --radiolist 生成单选列表（空格选择，回车确认）
#   5. 选择结果写入文件
#
# 支持的磁盘类型：
#   sd    — SATA/SCSI 磁盘（如 /dev/sda）
#   hd    — IDE 磁盘（老式）
#   vd    — virtio 虚拟磁盘（虚拟机）
#   nvme  — NVMe SSD（如 /dev/nvme0n1）
#   mmcblk — eMMC/SD 卡（如 /dev/mmcblk0）
dialog-what-disk-to-use() {
  # ${1:?} 取第一个参数，若为空则报错退出
  local file=${1:?}

  # lsblk -d 列出所有块设备（不含分区），awk 拼接为 "设备路径 大小 on" 格式，
  # grep 过滤出真实磁盘（sd/hd/vd/nvme/mmcblk），最终转为 Bash 数组
  devices_list=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' | grep -E 'sd|hd|vd|nvme|mmcblk'))

  # --radiolist 单选列表（空格选择，回车确认），--no-cancel 必须选一个
  # 15 60 4 = 高度、宽度、最多显示项数；2>"$file" 将选择结果写入文件（dialog 结果走 stderr）
  dialog --title "选择硬盘" --no-cancel --radiolist \
    "你要将系统安装到哪块硬盘？\n\n\
        用空格选择，回车确认。\n\n\
        警告：该硬盘上的所有数据将被摧毁！" 15 60 4 "${devices_list[@]}" 2>"$file"
}

# ----------------------------------------------------------------------------
# dialog-what-swap-size — 输入 Swap 文件大小的对话框
# ----------------------------------------------------------------------------
# 默认 8G，如果用户输入的不是纯数字则使用默认值
# 正则 ^[0-9]+$ 匹配一个或多个数字
dialog-what-swap-size() {
  local default_size="8"
  local file=${1:?}
  dialog --no-cancel --inputbox "将创建三个分区：Boot、Root 和 Swap\n\
        Boot 分区大小为 512M\n\
        Root 分区占用剩余空间\n\
        请输入 Swap 大小（仅填数字，如 4）。\n\n\
        如果不输入：\n\
            swap -> ${default_size}G \n\n" 20 60 2>"$file"

  local size=$(cat "$file")
  [[ $size =~ ^[0-9]+$ ]] || size=$default_size

  echo "$size" >"$file"
}

# ----------------------------------------------------------------------------
# set-timedate — 启用 NTP 时间同步
# ----------------------------------------------------------------------------
# 确保系统时钟准确，pacman 需要正确的时钟来验证 TLS 证书
set-timedate() {
  timedatectl set-ntp true
}

# ----------------------------------------------------------------------------
# dialog-how-wipe-disk — 选择磁盘擦除方式的对话框（当前未使用）
# ----------------------------------------------------------------------------
# 三种方式：
#   1) dd      — 用零覆写整个磁盘（慢，约 1M 块写入）
#   2) shred   — 多次随机覆写，更安全但更慢
#   3) 跳过    — 磁盘已空，无需擦除
dialog-how-wipe-disk() {
  local -r hd=${1:?}
  local -r file=${2:?}

  dialog --no-cancel \
    --title "清除所有数据" \
    --menu "选择清除硬盘数据的方式（$hd）" 15 60 4 \
    1 "使用 dd（全盘覆写）" \
    2 "使用 shred（慢但更安全）" \
    3 "不需要 - 硬盘已经是空的" 2>"$file"
}

# ----------------------------------------------------------------------------
# erase-disk — 按选择方式擦除磁盘（当前未使用）
# ----------------------------------------------------------------------------
# set +e 临时关闭错误退出，因为 dd/shred 可能因磁盘大小问题返回非零
# 用 dialog --progressbox 显示进度
erase-disk() {
  local -r choice=${1:?}
  local -r hd=${2:?}

  set +e
  case $choice in
  1) dd if=/dev/zero of="$hd" bs=1M status=progress 2>&1 | dialog --title "Formatting $hd..." --progressbox --stdout 20 65 ;;
  2) shred -v "$hd" | dialog --title "Formatting $hd..." --progressbox --stdout 20 60 ;;
  3) ;;
  esac
  set -e
}

# ----------------------------------------------------------------------------
# wipe-fs — 擦除磁盘上所有分区的文件系统签名
# ----------------------------------------------------------------------------
# wipefs -a  擦除所有签名（UUID、标签、文件系统类型等）
# wipefs -f  强制操作，不提示确认
#
# lsblk -ln -o NAME  以裸格式（无表头）列出所有分区名
# sort -r  倒序排列（sda3→sda2→sda1），确保从高编号分区开始擦除
# 这样可以避免擦除低编号分区后分区表变化导致高编号设备节点消失
wipe-fs() {
  local -r hd=${1:?}

  local parts=$(lsblk $hd -ln -o NAME | sort -r)
  for part in $parts; do
    wipefs -a -f /dev/$part
  done
}

# ----------------------------------------------------------------------------
# boot-partition — 根据 UEFI/BIOS 模式返回 fdisk 分区类型 ID
# ----------------------------------------------------------------------------
# 返回值：
#   UEFI 模式 → 1 (EFI System Partition，GPT 类型代码)
#   BIOS 模式 → 4 (BIOS Boot Partition，GRUB 在 GPT 磁盘上需要此类型)
#
# 💡 fdisk 中的 't' 命令用于更改分区类型，后面的数字就是类型代码
boot-partition() {
  local -r uefi=${1:?}
  local boot_partition_type=1
  [[ "$uefi" == 0 ]] && local boot_partition_type=4

  echo "$boot_partition_type"
}

# ----------------------------------------------------------------------------
# fdisk-partition — 使用 fdisk 创建 GPT 分区表和分区
# ----------------------------------------------------------------------------
# 流程（通过 heredoc <<EOF 传入 fdisk 的交互式命令序列）：
#
#   g              创建新的空 GPT 分区表（⚠️ 会清除原有分区表）
#   n ↵ ↵ +512M   新建分区1（默认起始扇区，大小 512M）— Boot 分区
#   t <type_id>    设置分区1的类型（UEFI=1, BIOS=4）
#   n ↵ ↵ ↵       新建分区2（默认起始扇区，占满剩余空间）— Root 分区
#   w              写入分区表到磁盘并退出
#
# 空行 = 按回车（接受默认值，即使用第一个可用的扇区）
#
# partprobe 通知内核重新读取分区表，确保 fdisk 的更改立即生效
fdisk-partition() {
  local -r hd=${1:?}
  local -r boot_partition_type=${2:?}
  # local -r swap_size=${3:?}

  partprobe "$hd"

  #g - create non empty GPT partition table
  #n - create new partition
  #p - primary partition
  #e - extended partition
  #w - write the table to disk and exit
  #空行表示回车
  #使用fdisk分区
  fdisk "$hd" <<EOF
g
n


+512M
t
$boot_partition_type
n



w
EOF
}

# ----------------------------------------------------------------------------
# format-partitions — 格式化分区并挂载到 /mnt
# ----------------------------------------------------------------------------
# NVMe 磁盘特殊处理：
#   SATA 磁盘分区名为 /dev/sda1, /dev/sda2 ...
#   NVMe 磁盘分区名为 /dev/nvme0n1p1, /dev/nvme0n1p2 ...（多了一个 'p'）
#   所以检测到 nvme 时在设备路径后追加 'p'
#
# 挂载结构：
#   /mnt           ← 分区2（Root，ext4）
#   /mnt/boot/efi  ← 分区1（Boot，FAT32，仅 UEFI 模式）
#
# FAT32 是 EFI 标准要求的文件系统格式，BIOS 模式不需要单独格式化 Boot 分区
format-partitions() {
  local hd=${1:?}
  local -r uefi=${2:?}

  # NVMe / eMMC 磁盘分区名带 'p'（nvme0n1p1 / mmcblk0p1 vs sda1）
  echo "$hd" | grep -E 'nvme|mmcblk' &>/dev/null && hd="${hd}p"

  # 格式化并挂载 Root 分区
  mkfs.ext4 "${hd}2"
  mount "${hd}2" /mnt

  # UEFI 模式：格式化 Boot 分区为 FAT32 并挂载
  log INFO "$uefi" "$output"
  [[ "$uefi" == 1 ]] &&
    mkfs.fat -F32 "${hd}1" &&
    mkdir -p /mnt/boot/efi &&
    mount "${hd}"1 /mnt/boot/efi
}

# ----------------------------------------------------------------------------
# select-mirror-source — 配置 pacman 国内镜像源
# ----------------------------------------------------------------------------
# 1. 停止 reflector 服务（Arch 自带的镜像自动选择工具，会覆盖我们的设置）
# 2. 在 mirrorlist 文件头部插入两个国内镜像源（头部 = 最高优先级）：
#    - 中科大 mirrors.ustc.edu.cn
#    - 清华 mirrors.tuna.tsinghua.edu.cn
#
# sed -i "1i ..."  在第一行前插入文本
select-mirror-source() {
  systemctl stop reflector.service
  sed -i "1i Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch\nServer = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch" /etc/pacman.d/mirrorlist
}

# ----------------------------------------------------------------------------
# install-arch-linux — 安装 Arch Linux 基础系统
# ----------------------------------------------------------------------------
# pacstrap: Arch 专用的系统安装工具，在指定目录下安装完整的根文件系统
# 参数 /mnt 表示安装到 /mnt 目录（即我们之前挂载的 Root 分区）
#
# 安装最小基础系统（其余软件由 install_3_apps.sh 通过 CSV 文件安装）：
#   🏗️ 基础：base linux linux-firmware
#   🔧 引导：grub base-devel efibootmgr
#   🌐 网络：iwd（WiFi）dhcpcd（有线）
#   💻 开发：git（版本控制）
#
# genfstab -U /mnt >>/mnt/etc/fstab
#   自动生成文件系统挂载表（fstab），新系统启动时根据此文件自动挂载分区
#   -U 使用 UUID 标识分区（比设备名更稳定，不会因磁盘插拔顺序变化）
install-arch-linux() {
  pacstrap /mnt base linux linux-firmware grub \
    base-devel efibootmgr \
    iwd dhcpcd git

  genfstab -U /mnt >>/mnt/etc/fstab
}

# ----------------------------------------------------------------------------
# install-chroot — chroot 进入新系统执行第二阶段脚本
# ----------------------------------------------------------------------------
# 1. 从远程仓库下载 install_2_chroot.sh 到新系统的根目录
# 2. arch-chroot /mnt 切换根目录到新安装的系统
# 3. 在新系统环境中执行 install_2_chroot.sh
#
# 💡 远程下载实现脚本热更新：修改仓库中的脚本后无需重新制作 ISO
# 💡 此时第二阶段脚本可以读取 /mnt/var_* 文件获取变量
install-chroot() {
  local -r installer_url=${1:?}

  curl "$installer_url/install_2_chroot.sh" >/mnt/install_2_chroot.sh
  arch-chroot /mnt bash install_2_chroot.sh
}

# ----------------------------------------------------------------------------
# clean — 清理临时变量文件
# ----------------------------------------------------------------------------
# 删除之前保存到 /mnt/ 下的临时状态文件
# 这些文件只在 run() 函数中写入、在第二阶段脚本中读取，完成后即可删除
clean() {
  rm /mnt/var_uefi
  rm /mnt/var_disk
  rm /mnt/var_hostname
  rm /mnt/var_output
  rm /mnt/var_dry_run
  rm /mnt/var_swap_size
  rm /mnt/var_root_pass
  rm /mnt/var_user_pass
  rm /mnt/var_selected_apps
  rm /mnt/var_url_installer
  rm /mnt/var_user_name
}

# ----------------------------------------------------------------------------
# end-of-install — 安装完成对话框
# ----------------------------------------------------------------------------
# dialog --yesno 返回值：
#   0 = 用户选了"是"
#   1 = 用户选了"否"
# 选"是" → reboot 重启进入新安装的系统
# 选"否" → clear 清屏，留在 Live USB 环境（可手动检查或继续调试）
end-of-install() {
  dialog --title "安装完成" \
    --yesno "恭喜！Arch Linux 安装完成！\n\n要进入图形界面，需要重启电脑。\n\n现在重启吗？" 20 60

  response=$?
  case $response in
  0) reboot ;;
  1) clear ;;
  esac

  clear
}

# ============================================================================
# 脚本入口：将所有命令行参数传给 run 函数
# ============================================================================
run "$@"
