#!/bin/bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
set -euo pipefail

run() {
    output=$(cat /var_output)
    log INFO "FETCH VARS FROM FILES" "$output"
    uefi=$(cat /var_uefi)
    hd=$(cat /var_disk)
    hostname=$(cat /var_hostname)
    url_installer=$(cat /var_url_installer)
    dry_run=$(cat /var_dry_run)

    ## 安装dialog
    log INFO "INSTALL DIALOG" "$output"
    install-dialog

    ## 安装并设置grub
    log INFO "INSTALL GRUB ON $hd WITH UEFI $uefi" "$output"
    install-grub "$hd" "$uefi"

    ## 设置硬件时间
    log INFO "SET HARDWARE CLOCK" "$output"
    set-hardware-clock

    ## 设置时区
    log INFO "SET TIMEZONE" "$output"
    # timedatectl set-timezone "Europe/Berlin"
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    hwclock --systohc

    ## 写入主机名
    log INFO "WRITE HOSTNAME: $hostname" "$output" \
    write-hostname "$hostname"

    ## 配置locale
    log INFO "CONFIGURE LOCALE" "$output"
    configure-locale "en_US.UTF-8" "UTF-8"

    ## root用户设置
    log INFO "ADD ROOT" "$output"
    # dialog --title "root password" --msgbox "It's time to add a password for the root user" 10 60
    config_user root

    ## 添加用户
    log INFO "ADD USER" "$output"
    # dialog --title "Add User" --msgbox "We can't always be root. Too many responsibilities. Let's create another user." 10 60

    config_user

    ## 进入下一步，安装应用
    continue-install "$url_installer"
}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

write-hostname() {
    local -r hostname=${1:?}
    echo "$hostname" > /etc/hostname
}

install-dialog() {
    pacman --noconfirm --needed -S dialog
}

install-grub() {
    local -r hd=${1:?}
    local -r uefi=${2:?}

    # pacman -S --noconfirm grub

    if [ "$uefi" = 1 ]; then
        pacman -S --noconfirm efibootmgr
        grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
    else
        grub-install "$hd"
    fi

    grub-mkconfig -o /boot/grub/grub.cfg
}

set-timezone() {
    local -r tz=${1:?}
    timedatectl set-timezone "$tz"
}

set-hardware-clock() {
    hwclock --systohc
}

configure-locale() {
    local -r locale=${1:?}
    local -r encoding=${2:?}

    echo "$locale $encoding" >> /etc/locale.gen
    locale-gen
    echo "LANG=$locale" > /etc/locale.conf
}

config_user() {
    local name=${1:-none}
    local def_name=eli

    pass1=root
    if [ "$name" == none ]; then
        # dialog --no-cancel --inputbox "Please enter your username" 10 60 2> name
        # name=$(cat name) && rm name
        name=$def_name
        pass1=$def_name
    fi

    # dialog --no-cancel --passwordbox "Enter your password" 10 60 2> pass1
    # dialog --no-cancel --passwordbox "Enter your password again. To be sure..." 10 60 2> pass2

    # while [ "$(cat pass1)" != "$(cat pass2)" ]
    # do
    #     dialog --no-cancel --passwordbox "Passwords do not match.\n\nEnter password again." 10 60 2> pass1
    #     dialog --no-cancel --passwordbox "Retype password." 10 60 2> pass2
    # done
    # pass1=$(cat pass1)

    # rm pass1 pass2

    # Create user if doesn't exist
    if [[ ! "$(id -u "$name" 2> /dev/null)" ]]; then
        dialog --infobox "Adding user $name..." 4 50
        # useradd -m -g wheel -s /bin/bash "$name"
        useradd -m -s /bin/bash "$name"
    fi

    # Add password to user
    echo "$name:$pass1" | chpasswd

    # Save name for later
    echo "$name" > /tmp/var_user_name
}

continue-install() {
    local -r url_installer=${1:?}

    # dialog --title "Continue installation" --yesno "Do you want to install all the softwares and the dotfiles?" 10 60 \
        # && curl "$url_installer/install_apps.sh" > /tmp/install_apps.sh \
        # && bash /tmp/install_apps.sh
        
    curl "$url_installer/install_apps.sh" > /tmp/install_apps.sh
    bash /tmp/install_apps.sh
}

run "$@"
