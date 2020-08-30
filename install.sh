#!/bin/bash

# This script will expect a couple things before running:
# There are 3 partitions created with a GPT partition table.
#   - Partition 1: 256MB EFI System partition
#   - Partition 2: 512MB boot partition
#   - Partition 3: rest of space root partition
# It will also assume that the internet connection is working
# and the partitions are empty. 

drivename=/dev/sda
mntroot=/mnt
ramsize=16996
me=`basename "$0"`
hostname="NEB-9.2OH"

modprobe dm-crypt
modprobe dm-mod

boot () {
    echo "Opening LUKS Root partition..."
    cryptsetup open ${drivename}3 luks_root
    echo "Mounting LUKS Root on /mnt"
    mount /dev/mapper/luks_root $mntroot
    echo "Mounting boot partition on mntroot"
    mount ${drivename}2 ${mntroot}/boot
    mount ${drivename}1 ${mntroot}/boot/efi
    echo "System should be ready to go! Feel free to arch-chroot now!"
}

iso () {
    cryptsetup luksFormat -v -s 512 -h sha512 ${drivename}3
    cryptsetup open ${drivename}3 luks_root
    mkfs.vfat -n "EFI System Partition" ${drivename}1
    mkfs.ext4 -L boot ${drivename}2
    mkfs.ext4 -L root /dev/mapper/luks_root
    mount /dev/mapper/luks_root ${mntroot}
    cd ${mntroot}
    mkdir boot
    mount ${drivename}2 boot
    mkdir boot/efi
    mount ${drivename}1 boot/efi
    dd if=/dev/zero of=swap bs=1M count=${ramsize}
    mkswap swap
    swapon swap
    chmod 0600 swap
    pacstrap -i ${mntroot} base base-devel efibootmgr grub neovim git
    genfstab -U /mnt > /mnt/etc/fstab
    cp $me $mntroot
    echo "Run the script again !"
    arch-chroot /mnt
}

chrooted () {
    passwd
    echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
    locale-gen
    echo LANG="en_US.UTF-8" > /etc/locale.conf
    export LANG="en_US.UTF-8"
    ln -sf /usr/share/zoneinfo/America/Denver /etc/localetime
    hwclock --systohc --utc
    echo $hostname > /etc/hostname
    echo "127.0.0.1     localhost $hostname"
        echo "::1           localhost $hostname"
}

install () {
    echo "-------------------------------"
    echo "| 1) I am in the install ISO  |"
    echo "| 2) I am chrooted in the ISO |"
    echo "| 2) I am booted into a DE/WM |"
    echo "-------------------------------"
    read -n 1 -p "Please enter a number (1, 2, 3): " ans
    case $ans in 
        1) 
            iso;;
        2)
            chrooted;;
        3)
            de;;
        *)
            echo "unknown"; exit;;
    esac
}


menu () {
    echo "-----------------------------------"
    echo "| 1) Install system from scratch  |"
    echo "| 2) Boot into repair environment |"
    echo "-----------------------------------"
    read -n 1 -p "Please enter a number (1, 2): " ans
    case $ans in
        1)
            install;;
        2)
            boot;;
        *)
            echo "unknown"; exit;;
    esac
}

menu;;
