# Arch Linux 自动安装脚本

这是一组用于自动安装 Arch Linux 的脚本。

**⚠️ 警告**：本脚本仅供参考，请勿直接在你的系统上运行。如果你想试用（建议使用虚拟机），需要：

1. `curl` 下载第一个脚本 `install_1_sys.sh`（`curl -LfO https://gitee.com/unityw/ArchInstall/raw/master/install_1_sys.sh && sh install_1_sys.sh`）
2. 根据需要修改文件中的 `url-installer` 和 `repo-installer` 函数
3. 运行

然后按照提示操作即可。

## 📦 脚本说明

所有脚本从 `install_1_sys.sh` 开始，自动链式调用。

**`install_1_sys.sh`**（Live USB 环境）：
1. 配置国内镜像源、同步时钟
2. 安装 kmscon + 中文字体（自动切换到中文终端）
3. 交互式输入：root 密码、主机名、用户密码、Swap 大小
4. 选择目标磁盘
5. 从远程仓库下载 CSV，选择要安装的软件（dialog checklist）
6. 擦除磁盘、创建 GPT 分区（Boot 512M + Root 占满，使用 sfdisk）
7. pacstrap 安装最小基础系统
8. arch-chroot 进入新系统执行第二阶段

**`install_2_chroot.sh`**（chroot 环境，root 身份）：
1. 创建 Swap 文件
2. 安装 GRUB 引导
3. 设置硬件时钟、时区、locale
4. 设置 root 密码
5. 创建普通用户（用户名 = 主机名）
6. 设置主机名

**`install_3_apps.sh`**（chroot 环境，root 身份）：
1. 添加 archlinuxcn 仓库
2. 安装 yay + v2raya（必装软件）
3. 启用网络服务（iwd、dhcpcd）
4. 设置 sudo 权限
5. 保存用户选择的软件列表到用户主目录

**`install_4_user.sh`**（chroot 环境，普通用户身份）：
1. 创建用户目录

**`install_5_apps.sh`**（进入系统后手动执行）：
1. 安装用户选择的软件（yay）
2. 启用系统服务（`scripts/enable-services.sh`）
3. 应用配置（`scripts/config-apps.sh`）

用法：`bash install_5_apps.sh`（自动读取安装时保存的配置，无需传参）

## 📂 目录结构

```
apps/                       软件列表 CSV（按分类）
  ai.csv                    AI 工具
  audio.csv                 音频 / 蓝牙
  base.csv                  基础系统（必装）
  chinese.csv               中文支持
  desktop.csv               桌面环境
  dev.csv                   开发工具
  network.csv               网络工具
  shell.csv                 Shell
  tools.csv                 实用工具

files/                      纯配置文件
  i3/config                 i3 窗口管理器配置
  sddm.conf                 SDDM 登录管理器配置
  sudoers                   sudo 权限配置
  v2raya/                   v2rayA 代理配置

scripts/                    可执行脚本（按需修改）
  enable-services.sh        启用系统服务
  config-apps.sh            应用配置（系统级 + 用户级合并）
```

## 📋 CSV 格式

```
包名,说明,优先级
```

优先级：
* **必装** — 脚本自动安装，不出现在选择界面
* **默认** — 预选中，用户可取消
* **可选** — 未选中，用户手动勾选
