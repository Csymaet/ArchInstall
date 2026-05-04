# Arch Linux 自动安装脚本

这是一组用于自动安装 Arch Linux 的脚本。

**⚠️ 警告**：本脚本仅供参考，请勿直接在你的系统上运行。如果你想试用（建议使用虚拟机），需要：

1. `curl` 下载第一个脚本 `install_1_sys.sh`（`curl -LO https://raw.githubusercontent.com/Csymaet/ArchInstall/master/install_1_sys.sh && sh install_1_sys.sh`）
2. 根据需要修改文件中的 `url_installer` 函数。
3. 运行。

然后按照提示操作即可。

## 📦 脚本说明

所有脚本都从 `install_1_sys.sh` 调用。

**第一个脚本 `install_1_sys.sh`**：
1. 清空所选磁盘上的所有数据
2. 创建分区
    * Boot 分区 200M
    * Swap 分区
    * Root 分区

**第二个脚本 `install_2_chroot.sh`**：
1. 设置 locale / 时区
2. 配置 Grub 引导

**第三个脚本 `install_3_apps.sh`**：
1. 创建新用户并设置密码
2. 安装 `apps/` 目录下各分类 CSV 中列出的软件
3. 安装 `composer`（PHP 包管理器）

**第四个脚本 `install_4_user.sh`**：
1. 通过 yay（AUR 仓库）安装 pacman 未找到的软件
2. 部署 dotfiles 配置文件

## 💻 安装了哪些软件？

打开 `apps/` 目录下的各分类 CSV 文件即可查看完整列表。
