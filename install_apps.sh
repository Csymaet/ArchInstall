#!/bin/bash

run() {
    output=$(cat /var_output)

    log INFO "FETCH VARS FROM FILES" "$output"
    name=$(cat /tmp/var_user_name)
    url_installer=$(cat /var_url_installer)
    dry_run=$(cat /var_dry_run)

    ## 下载apps.csv
    # log INFO "DOWNLOAD APPS CSV" "$output"
    # apps_path="$(download-app-csv "$url_installer")"
    # log INFO "APPS CSV DOWNLOADED AT: $apps_path" "$output"

    # 为steam添加multilib仓库
    # add-multilib-repo
    # log INFO "MULTILIB ADDED" "$output"
    
    # 添加cn仓库
    add-cn-repo
    log INFO "cn ADDED" "$output"

    # 安装yay
    log INFO "INSTALL YAY" "$output"
    install-yay "$output"

    ## 安装aur应用
    log INFO "INSTALL AUR APPS" "$output"
    install-aur-apps "$output"

    ## 启动服务
    log INFO "ENABLE SERVICE" "$output"
    enable-service "$output"
    
    ## 配置应用
    log INFO "CONFIG APPS" "$output"
    config-apps "$output"

    ## 显示软件选择界面
    # dialog-welcome
    # dialog-choose-apps ch # 会返回一系列名称，用空格分隔
    # choices=$(cat ch) && rm ch
    # log INFO "APP CHOOSEN: $choices" "$output"
    # lines="$(extract-choosed-apps "$choices" "$apps_path")" # 从apps.csv中提取出软件包的具体名称
    # log INFO "GENERATED LINES: $lines" "$output"
    # apps="$(extract-app-names "$lines")" # 提取第二列(软件包名称)
    # log INFO "APPS: $apps" "$output"
    
    ## 更新系统
    # update-system
    # log INFO "UPDATED SYSTEM" "$output"
    ## 清空previous-aur-queue
    # delete-previous-aur-queue
    # log INFO "DELETED PREVIOUS AUR QUEUE" "$output"
    ## 开始安装并设置
    # dialog-install-apps "$apps" "$dry_run" "$output"
    # log INFO "APPS INSTALLED" "$output"
    ## 关闭嘟嘟声
    # disable-horrible-beep
    # log INFO "HORRIBLE BEEP DISABLED" "$output"
    
    ## 设置sudo
    set-user-permissions
    log INFO "USER PERMISSIONS SET" "$output"
    
    ## 进入下一步"install_user"
    continue-install "$url_installer" "$name"
}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

download-app-csv() {
    local -r url_installer=${1:?}

    apps_path="/tmp/apps.csv"
    curl "$url_installer/apps.csv" > "$apps_path"

    echo $apps_path
}

# Add multilib repo for steam
add-multilib-repo() {
    echo "[multilib]" >> /etc/pacman.conf && echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
}

add-cn-repo() {
    echo "[archlinuxcn]" >> /etc/pacman.conf && echo "Server = https://mirrors.cloud.tencent.com/archlinuxcn/\$arch" >> /etc/pacman.conf
    pacman -Sy && pacman --noconfirm --needed -S archlinuxcn-keyring
}

install-yay() {
    pacman --noconfirm --needed -S yay
}

install-aur-apps() {
    yay --noconfirm -S v2ray v2raya zsh zsh-completions oh-my-zsh-git clitrans-git termscp sddm sddm-sugar-dark
}

enable-service() {
    systemctl enable docker.service
    systemctl enable dhcpcd.service
    systemctl enable sshd.service
    systemctl enable bluetooth.service
    systemctl enable v2ray.service
    systemctl enable v2raya.service
    systemctl enable sddm.service
}

config-apps() {
    # profile
    echo -e "\n# 进入我的目录\nif [ -d ~/myfile ]; then\n  cd ~/myfile\nfi" >> /etc/profile
    # sddm
    mkdir -p /etc/sddm.conf.d
    curl "$url_installer/files/sddm.conf" > /etc/sddm.conf.d/sddm.conf
    # docker
    gpasswd -a eli docker     #将登陆用户加入到docker用户组中
    # newgrp docker     #更新用户组
    # v2raya
    mkdir -p /etc/v2raya
    curl "$url_installer/files/v2raya/bolt.db" > /etc/v2raya/bolt.db
    curl "$url_installer/files/v2raya/boltv4.db" > /etc/v2raya/boltv4.db
    curl "$url_installer/files/v2raya/config.json" > /etc/v2raya/config.json

    # zsh
    chsh -s /bin/zsh eli
}

dialog-welcome() {
    dialog --title "Welcome!" --msgbox "Welcome to Phantas0s dotfiles and software installation script for Arch linux.\n" 10 60
}

dialog-choose-apps() {
    local file=${1:?}

    apps=("essential" "Essentials" on
        "compression" "Compression Tools" on
        "tools" "Very nice tools to have (highly recommended)" on
        "audio" "Audio tools" on
        "network" "Network Configuration" off
        "git" "Git & git tools" on
        "i3" "i3 Tile manager & Desktop" on
        "tmux" "Tmux" on
        "neovim" "Neovim" on
        "keyring" "Keyring applications" on
        "urxvt" "Urxvt unicode" on
        "zsh" "Unix Z-Shell (zsh)" on
        "ripgrep" "Ripgrep" on \
        "qutebrowser" "Qutebrowser" on
        "notify" "Notifications with dunst & libnotify" on
        "gtk" "GTK 3 themes and icons" on
        "programming" "Programming environments (PHP, Ruby, Go, Docker, Clojure)" on
        "keepass" "Keepass" on
        "sql" "Mysql (mariadb) & mysql tools" on
        "office" "Office tools (Libreoffice...)" off
        "multimedia" "Multimedia" off
        "videography" "Video creation" off
        "graphism" "Design" off
        "photography" "Photography tools" off
        "firefox" "Firefox (browser)" off
        "brave" "brave (browser)" off
        "newsboat" "RSS Feed Reader" on
        "joplin" "Note taking system" off
        "thunar" "Graphical file manager" off
        "thunderbird" "Thunderbird" off
        "pandoc" "Pandoc and usefull dependencies" off
        "syncthing" "Sync files via P2P" off
        "rover" "Simple file browser for the terminal" off
        "language" "Language tools" off
        "nextcloud" "Nextcloud client" off
        "hugo" "Hugo static site generator" off
        "freemind" "Freemind - mind mapping software" off
        "doublecmd" "Double Commander - File explorer a la FreeCommander" off
        "vmware" "Vmware tools" off
        "gaming" "Almost everything for gaming on Linux" off)

    dialog --checklist "You can now choose the groups of applications you want to install, according to your own CSV file.\n\n Press SPACE to select and ENTER to validate your choices." 0 0 0 "${apps[@]}" 2> "$file"
}

extract-choosed-apps() {
    local -r choices=${1:?}
    local -r apps_path=${2:?}

    selection="^$(echo $choices | sed -e 's/ /,|^/g'),"
    lines=$(grep -E "$selection" "$apps_path")

    echo "$lines"
}

extract-app-names() {
    local -r lines=${1:?}
    echo "$lines" | awk -F, '{print $2}'
}

update-system() {
    pacman -Syu --noconfirm
}

delete-previous-aur-queue() {
    rm -f /tmp/aur_queue
}

dialog-install-apps() {
    dialog --title "Let's go!" --msgbox \
    "The system will now install everything you need.\n\n\
    It will take some time.\n\n " 13 60
}

dialog-install-apps() {
    local -r final_apps=${1:?}
    local -r dry_run=${2:?}
    local -r output=${3:?}

    count=$(echo "$final_apps" | wc -l)

    c=0
    echo "$final_apps" | while read -r line; do
        c=$(( "$c" + 1 ))

        dialog --title "Arch Linux Installation" --infobox \
        "Downloading and installing program $c out of $count: $line..." 8 70

        if [ "$dry_run" = false ]; then
            pacman-install "$line" "$output"

            # Needed if system installed in VMWare
            if [ "$line" = "open-vm-tools" ]; then
                systemctl enable vmtoolsd.service
                systemctl enable vmware-vmblock-fuse.service
            fi

            if [ "$line" = "networkmanager" ]; then
                # Enable the systemd service NetworkManager.
                systemctl enable NetworkManager.service
            fi

            if [ "$line" = "zsh" ]; then
                # zsh as default terminal for user
                chsh -s "$(which zsh)" "$name"
            fi

            if [ "$line" = "docker" ]; then
                groupadd docker
                gpasswd -a "$name" docker
                systemctl enable docker.service
            fi

            if [ "$line" = "at" ]; then
                systemctl enable atd.service
            fi

            if [ "$line" = "mariadb" ]; then
                mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
            fi
        else
            fake_install "$line"
        fi
    done
}

fake-install() {
    echo "$1 fakely installed!" >> "$output"
}

pacman-install() {
    local -r app=${1:?}
    local -r output=${2:?}

    ((pacman --noconfirm --needed -S "$app" &>> "$output") || echo "$app" &>> /tmp/aur_queue)
}

continue-install() {
    local -r url_installer=${1:?}
    local -r name=${2:?}

    curl "$url_installer/install_user.sh" > /tmp/install_user.sh;

    if [ "$dry_run" = false ]; then
        # Change user and begin the install use script
        sudo -u "$name" bash /tmp/install_user.sh
    fi
}

set-user-permissions() {
    dialog --infobox "Copy user permissions configuration (sudoers)..." 4 40
    curl "$url_installer/files/sudoers" > /etc/sudoers
}

disable-horrible-beep() {
    rmmod pcspkr
    echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf
}

run "$@"
