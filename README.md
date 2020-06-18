# Phantas0s Arch Install

![Phantas0s Arch Install](screen.png "Phantas0s Arch Install")

This is my scripts to install easily Arch Linux.

**WARNING**: This set of script should be used for inspiration, don't run them on your system.

If you want to try to install everything (I would advise you to use a VM) you just have to `curl` the first script `install_sys.sh` and launch it:

`curl -O https://raw.githubusercontent.com/Phantas0s/ArchInstall/master/install_sys.sh && sh install_sys.sh`

Follow the instructions.

Don't expect a lot of choices though.

## What's in there? 

The first script `install_sys`.sh will:
1. Erase everything on `/dev/sda` **(!!!)**
2. Create partitions
    - Boot partition of 200M
    - Swap partition
    - Root partition
    - Home encrypted partition

The second script `install_chroot` will:
1. Set up locale / time
2. Set up Grub for the boot

The third script `install_root` will:
1. Create a new user with password
2. Install every software specified in `progs.csv`
3. Install `composer` (PHP package manager)

The fourth script `install_user` will:
1. Try to install every software not found by pacman with aurman (AUR repos)
2. Install my [dotfiles](https://github.com/Phantas0s/.dotfiles)

## What software are installed?

Opening `progs.csv` will answer your question.
