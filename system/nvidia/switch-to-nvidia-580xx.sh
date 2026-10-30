#!/bin/bash
# Switch from nvidia-open-dkms (broken on Pascal) to nvidia-580xx-dkms (AUR, supports Pascal)
set -e

echo "=== Step 1: Install AUR helper (yay) if missing ==="
if ! command -v yay >/dev/null; then
    sudo pacman -S --needed --noconfirm base-devel git
    cd ~
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf yay
fi

echo "=== Step 2: Remove all open nvidia packages together (nvidia-prime depends on nvidia-utils) ==="
sudo pacman -Rns --noconfirm nvidia-open-dkms nvidia-utils nvidia-prime || true

echo "=== Step 3: Install nvidia-580xx-dkms + nvidia-580xx-utils + nvidia-prime from AUR ==="
yay -S --noconfirm --answeredit N --answerclean N --removemake nvidia-580xx-dkms nvidia-580xx-utils nvidia-prime

echo "=== Step 4: Rebuild DKMS and regenerate initramfs ==="
sudo dkms autoinstall
sudo mkinitcpio -P

echo "=== Done! Reboot now: sudo reboot ==="
