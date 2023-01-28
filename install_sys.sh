#!/bin/bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
set -euo pipefail

# YOU NEED TO MODIFY YOUR INSTALL URL
url-installer() {
    # echo "https://raw.githubusercontent.com/Csymaet/ArchInstall/master"
    echo "192.168.1.145:8081"
}

run() {
    ## 有两个参数，分别是-o和-d
    local dry_run=${dry_run:-false}
    local output=${output:-/dev/tty2}

    while getopts d:o: option
    do
        case "${option}"
            in
            d) dry_run=${OPTARG};;
            o) output=${OPTARG};;
            *);;
        esac
    done

    log INFO "DRY RUN? $dry_run" "$output"

    ## 选择镜像源
    log INFO "SELECT MIRROR SOURCE" "$output"
    select-mirror-source

    ## 更新系统时钟
    log INFO "SET TIME" "$output"
    set-timedate

    # 安装"dialog"
    install-dialog
    dialog-are-you-sure

    ## 输入主机名称
    local hostname
    # dialog-name-of-computer hn
    # hostname=$(cat hn) && rm hn
    hostname=eli
    log INFO "HOSTNAME: $hostname" "$output"

    ## 选择磁盘
    local disk
    dialog-what-disk-to-use hd
    disk=$(cat hd) && rm hd
    log INFO "DISK CHOSEN: $disk" "$output"

    ## swap分区大小
    # local swap_size
    # dialog-what-swap-size swaps
    # swap_size=$(cat swaps) && rm swaps
    # log INFO "SWAP SIZE: $swap_size" "$output"

    ## 选择格盘方式
    local wiper
    dialog-how-wipe-disk "$disk" dfile
    wiper=$(cat dfile) && rm dfile
    log INFO "WIPER CHOICE: $wiper" "$output"

    ## 使用选择的方式格盘
    [[ "$dry_run" = false ]] \
        && log INFO "ERASE DISK" "$output" \
        && erase-disk "$wiper" "$disk"

    ## 创建分区
    [[ "$dry_run" = false ]] \
        && log INFO "CREATE PARTITIONS" "$output" \
        && fdisk-partition "$disk" "$(boot-partition "$(is-uefi)")" # "$swap_size"

    ## 格式化分区
    [[ "$dry_run" = false ]] \
        && log INFO "FORMAT PARTITIONS" "$output" \
        && format-partitions "$disk" "$(is-uefi)"

    ## 创建临时文件
    log INFO "CREATE VAR FILES" "$output"
    echo "$(is-uefi)" > /mnt/var_uefi
    echo "$disk" > /mnt/var_disk
    echo "$hostname" > /mnt/var_hostname
    echo "$output" > /mnt/var_output
    echo "$dry_run" > /mnt/var_dry_run
    url-installer > /mnt/var_url_installer

    ## 安装系统
    [[ "$dry_run" = false ]] \
        && log INFO "BEGIN INSTALL ARCH LINUX" "$output" \
        && install-arch-linux

    ## 进入下一步，进入新系统中执行"install-chroot"
    [[ "$dry_run" = false ]] \
        && log INFO "BEGIN CHROOT SCRIPT" "$output" \
        && install-chroot "$(url-installer)"

    clean
    end-of-install
}

log() {
    local -r level=${1:?}
    local -r message=${2:?}
    local -r output=${3:?}
    local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    echo -e "${timestamp} [${level}] ${message}" >>"$output"
}

install-dialog() {
    pacman -Sy
    pacman --noconfirm -S dialog
}

dialog-are-you-sure() {
    dialog --defaultno \
        --title "Are you sure?" \
        --yesno "This is my personnal arch linux install. \n\n\
        It will just DESTROY EVERYTHING on the hard disk of your choice. \n\n\
        Don't say YES if you are not sure about what you're doing! \n\n\
        Are you sure?"  15 60 || exit
}

dialog-name-of-computer() {
    local file=${1:?}
    dialog --no-cancel --inputbox "Enter a name for your computer." 10 60 2> "$file"
}

is-uefi() {
    local uefi=0
    ls /sys/firmware/efi/efivars &> /dev/null && uefi=1

    echo "$uefi"
}

dialog-what-disk-to-use() {
    local file=${1:?}

    devices_list=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' | grep -E 'sd|hd|vd|nvme|mmcblk'))
    dialog --title "Choose your hard drive" --no-cancel --radiolist \
        "Where do you want to install your new system?\n\n\
        Select with SPACE, valid with ENTER.\n\n\
        WARNING: Everything will be DESTROYED on the hard disk!" 15 60 4 "${devices_list[@]}" 2> "$file"
}

dialog-what-swap-size() {
    local default_size="8"
    local file=${1:?}
    dialog --no-cancel --inputbox "You need four partitions: Boot, Root and Swap \n\
        The boot will be 512M\n\
        The root will be the rest of the hard disk\n\
        Enter partitionsize in gb for the Swap. \n\n\
        If you dont enter anything: \n\
            swap -> ${default_size}G \n\n" 20 60 2> "$file"

    local size=$(cat "$file")
    [[ $size =~ ^[0-9]+$ ]] || size=$default_size

    echo "$size" > "$file"
}

set-timedate() {
    timedatectl set-ntp true
}

dialog-how-wipe-disk() {
    local -r hd=${1:?}
    local -r file=${2:?}

    dialog --no-cancel \
        --title "!!! DELETE EVERYTHING !!!" \
        --menu "Choose the way to destroy everything on your hard disk ($hd)" 15 60 4 \
        1 "Use dd (wipe all disk)" \
        2 "Use schred (slow & secure)" \
        3 "No need - my hard disk is empty" 2> "$file"
}

erase-disk() {
    local -r choice=${1:?}
    local -r hd=${2:?}

    set +e
    case $choice in
        1) dd if=/dev/zero of="$hd" bs=1M status=progress 2>&1 | dialog --title "Formatting $hd..." --progressbox --stdout 20 65;;
        2) shred -v "$hd" | dialog --title "Formatting $hd..." --progressbox --stdout 20 60;;
        3) ;;
    esac
    set -e
}

boot-partition() {
    local -r uefi=${1:?}
    local boot_partition_type=1
    [[ "$uefi" == 0 ]] && local boot_partition_type=4

    echo "$boot_partition_type"
}

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


+2G
t
$boot_partition_type
n


+100G
n



w
EOF
}

format-partitions() {
    local hd=${1:?}
    local -r uefi=${2:?}

    echo "$hd" | grep -E 'nvme' &> /dev/null && hd="${hd}p"

    # mkswap "${hd}2"
    # swapon "${hd}2"

    mkfs.ext4 "${hd}2"
    mount "${hd}2" /mnt

    mkfs.ext4 "${hd}3"
    mkdir -p /mnt/home
    mount "${hd}3" /mnt/home

    log INFO "$uefi" "$output"
    [[ "$uefi" == 1 ]] && \
        mkfs.fat -F32 "${hd}1" && \
        mkdir -p /mnt/boot/efi && \
        mount "${hd}"1 /mnt/boot/efi
}

select-mirror-source() {
    systemctl stop reflector.service
    sed -i "1i Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch\nServer = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch" /etc/pacman.d/mirrorlist
}


install-arch-linux() {
    pacstrap /mnt linux base base-devel linux-firmware grub efibootmgr iwd dhcpcd man-db git neovim openssh
    genfstab -U /mnt >> /mnt/etc/fstab
}

install-chroot() {
    local -r installer_url=${1:?}

    curl "$installer_url/install_chroot.sh" > /mnt/install_chroot.sh
    arch-chroot /mnt bash install_chroot.sh
}

clean() {
    rm /mnt/var_uefi
    rm /mnt/var_disk
    rm /mnt/var_hostname
    rm /mnt/var_output
    rm /mnt/var_dry_run
}

end-of-install() {
    dialog --title "Reboot time" \
        --yesno "Congrats! The install is done! \n\nTo run the new graphical environment, you need to restart your computer. \n\nDo you want to restart now?" 20 60

    response=$?
    case $response in
        0) reboot;;
        1) clear;;
    esac

    clear
}

run "$@"
