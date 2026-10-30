# ASUS VivoBook X512JP — Complete Setup Guide

> Hardware: ASUS VivoBook X512JP  
> OS: Arch Linux  
> Desktop: KDE Plasma  
> Kernel: 6.18.38-2-lts (linux-lts)

This guide covers two setup tasks:
1. **Fingerprint sensor** (ELAN ELAN7001 / eFSA80SC, touchpad PID 04f3:3087)
2. **NVIDIA GPU** (GeForce MX330, Pascal, dual-graphics with Intel Iris Plus G7)

After a fresh Arch install, follow each part in order.

---

# Part A — Fingerprint Sensor

## A1. Install system packages

```bash
sudo pacman -S --needed --noconfirm \
    meson ninja pkgconf gtk-doc \
    gobject-introspection libgudev pixman \
    libusb openssl fprintd opencv doctest

# Verify pam_fprintd is included inside fprintd package
pacman -Ql fprintd | grep pam_fprintd
# should show: /usr/lib/security/pam_fprintd.so

# Add yourself to the input group (required for device access)
sudo usermod -aG input $USER

# Start/enable fprintd (D-Bus activated)
sudo systemctl start fprintd.service
```

**Reboot or log out and back in** so the `input` group change takes effect.

## A2. Verify the sensor is detected

```bash
ls /sys/bus/spi/devices/ | grep ELAN
ls -l /dev/spidev*
```

If `/dev/spidev*` is missing, you need the udev rules in A3 first.

## A3. Udev rules and spidev buffer

Create `/etc/udev/rules.d/99-elan-fingerprint.rules`:

```
SUBSYSTEM=="spi", ATTRS{modalias}=="acpi:ELAN7001:", ENV{DRIVER_OVERRIDE}="spidev"
SUBSYSTEM=="spidev", ATTRS{modalias}=="acpi:ELAN7001:", MODE="0660", GROUP="input"
```

Apply:

```bash
cd /etc/udev/rules.d
sudo tee 99-elan-fingerprint.rules > /dev/null <<'EOF'
SUBSYSTEM=="spi", ATTRS{modalias}=="acpi:ELAN7001:", ENV{DRIVER_OVERRIDE}="spidev"
SUBSYSTEM=="spidev", ATTRS{modalias}=="acpi:ELAN7001:", MODE="0660", GROUP="input"
EOF
cd ~

sudo udevadm control --reload-rules
sudo udevadm trigger
```

Create `/etc/modprobe.d/spidev-bufsiz.conf`:

```
options spidev bufsiz=32768
```

Apply:

```bash
sudo modprobe -r spidev 2>/dev/null
sudo modprobe spidev bufsiz=32768

# Verify
if [ "$(cat /sys/module/spidev/parameters/bufsiz)" = "32768" ]; then
    echo "OK: spidev bufsiz = 32768"
else
    echo "ERROR: bufsiz not set correctly"
fi
```

## A4. Fix missing glib-mkenums (Arch packaging quirk)

If `/usr/bin/glib-mkenums` is missing:

```bash
SRC=$(find ~/.local/share/flatpak -name glib-mkenums -type f 2>/dev/null | head -1)
if [ -z "$SRC" ]; then
    echo "ERROR: install a GNOME Platform Flatpak runtime first"
    exit 1
fi
sudo cp "$SRC" /usr/local/bin/glib-mkenums
sudo chmod +x /usr/local/bin/glib-mkenums
sudo ln -sf /usr/local/bin/glib-mkenums /usr/bin/glib-mkenums
```

Create opencv4.pc symlink (OpenCV 5 provides opencv5.pc, SIGFM asks for opencv4):

```bash
sudo ln -sf /usr/lib/pkgconfig/opencv5.pc /usr/lib/pkgconfig/opencv4.pc
pkg-config --modversion opencv4
```

## A5. Clone and patch libfprint (SIGFM)

```bash
mkdir -p ~/build && cd ~/build
git clone https://github.com/goodix-fp-linux-dev/libfprint.git libfprint-sigfm
cd libfprint-sigfm
git checkout sigfm
```

Edit `libfprint/drivers/elanspi.c`. Apply three changes for the eFSA80SC small sensor:

**Change 1 — image pipeline in `elanspi_fp_frame_stitch_and_submit`:**

Replace:
```c
  img = fpi_assemble_frames (&assembling_ctx, frame_start);
  scaled = fpi_image_resize (img, 2, 2);

  scaled->flags |= FPI_IMAGE_PARTIAL | FPI_IMAGE_COLORS_INVERTED;

  /* submit image */
  fpi_image_device_image_captured (FP_IMAGE_DEVICE (self), g_steal_pointer (&scaled));
```

With:
```c
  img = fpi_assemble_frames (&assembling_ctx, frame_start);

  img->flags |= FPI_IMAGE_COLORS_INVERTED;

  /* submit image */
  fpi_image_device_image_captured (FP_IMAGE_DEVICE (self), g_steal_pointer (&img));
```

This drops the 2× upscale (the native 10px ridge period is already ideal) and the FPI_IMAGE_PARTIAL flag (which would cull 70-85% of features on this narrow strip). You can also delete the now-unused `g_autoptr(FpImage) scaled = NULL;` declaration line above.

**Change 2 — algorithm + threshold in `fpi_device_elanspi_class_init`:**

Replace:
```c
  img_class->bz3_threshold = 24;
  img_class->img_open = elanspi_open;
```

With:
```c
  img_class->bz3_threshold = 100;
  img_class->algorithm = FPI_DEVICE_ALGO_SIGFM;
  img_class->img_open = elanspi_open;
```

`bz3_threshold = 100` is more permissive (default 24 is too strict for the small sensor). `FPI_DEVICE_ALGO_SIGFM` switches the matcher from the default NBIS/bozorth3 (which cannot discriminate fingers on this 80×80 sensor) to the SIFT-based SIGFM matcher.

**Optional — try different rotations** if your unit's accuracy is still poor. Edit `libfprint/drivers/elanspi.h`, find the 0x3087 entry:

```c
{.udev_types = ELANSPI_UDEV_TYPES, .spi_acpi_id = "ELAN7001",
 .hid_id = {.vid = ELANSPI_TP_VID, .pid = 0x3087},
 .driver_data = ELANSPI_180_ROTATE},   // <-- try ELANSPI_NO_ROTATE, _90LEFT, _90RIGHT
```

After each rotation change: rebuild, reinstall, restart fprintd, delete enrollment, re-enroll, test 5 verifies.

## A6. Build and install

```bash
cd ~/build/libfprint-sigfm
rm -rf build
meson setup build --prefix=/usr/local \
    -Ddrivers=elanspi \
    -Dudev_rules=disabled \
    -Ddoc=false
ninja -C build
sudo ninja -C build install

# Register /usr/local/lib in the loader
echo "/usr/local/lib" | sudo tee /etc/ld.so.conf.d/usr_local_lib.conf
sudo ldconfig
```

## A7. Restart fprintd and enroll

```bash
sudo systemctl restart fprintd.service
fprintd-list $(whoami)
fprintd-enroll
# Repeat slow swipes until "enroll-completed"
```

Test:

```bash
fprintd-verify      # same finger — should match
fprintd-verify      # wrong finger — must not match
```

## A8. Enable fingerprint for sudo (NOT for first login)

```bash
sudo sed -i '2i auth sufficient pam_fprintd.so' /etc/pam.d/sudo
head -5 /etc/pam.d/sudo

sudo -k
sudo echo test-fingerprint
# Should prompt: "Swipe your right index finger across the fingerprint reader"
```

## A9. Enable fingerprint for KDE lock screen / after sleep

```bash
cd /etc/pam.d
sudo tee kde > /dev/null <<'EOF'
#%PAM-1.0

auth       sufficient pam_fprintd.so
auth       include    system-auth

account    include    system-auth
password   include    system-auth
session    include    system-auth
EOF

sudo tee kde-fingerprint > /dev/null <<'EOF'
#%PAM-1.0

auth       sufficient pam_fprintd.so
auth       include    system-auth

account    include    system-auth
password   include    system-auth
session    include    system-auth
EOF
cd ~
```

## A10. Rebuild after system updates

```bash
cd ~/build/libfprint-sigfm
rm -rf build
meson setup build --prefix=/usr/local \
    -Ddrivers=elanspi \
    -Dudev_rules=disabled \
    -Ddoc=false
ninja -C build
sudo ninja -C build install
sudo ldconfig
sudo systemctl restart fprintd.service
fprintd-delete $(whoami)
fprintd-enroll
```

---

# Part B — NVIDIA GPU (GeForce MX330, Pascal)

> **Important for ASUS VivoBook X512JP:** Arch dropped Pascal support in driver 590. The official `nvidia-dkms` package no longer exists; it was replaced by `nvidia-open-dkms`, which does **not** support Pascal GPUs. We must install the legacy `nvidia-580xx-dkms` from AUR.

## B1. Run the switch script

A helper script is at `~/Desktop/switch-to-nvidia-580xx.sh`. It installs `yay` (AUR helper), removes the broken `nvidia-open-dkms`, and installs `nvidia-580xx-dkms` + `nvidia-580xx-utils` from AUR.

```bash
chmod +x ~/Desktop/switch-to-nvidia-580xx.sh
~/Desktop/switch-to-nvidia-580xx.sh
```

If pacman asks about removing the `nvidia-prime` package as a dependency, say **y**.

After it finishes:

```bash
sudo reboot
```

## B2. Verify

```bash
nvidia-smi
# Should show: NVIDIA GeForce MX330, Driver Version: 580.173.02

prime-run glxinfo -B | grep -iE "OpenGL vendor|OpenGL renderer"
# Should show: NVIDIA Corporation / GeForce MX330
```

## B3. Blacklist nouveau and load NVIDIA modules

These are handled by the AUR package's hooks, but verify:

```bash
cd /etc/modprobe.d
echo "blacklist nouveau" | sudo tee blacklist-nouveau.conf > /dev/null
echo "options nouveau modeset=0" | sudo tee -a blacklist-nouveau.conf > /dev/null
cd /etc/modules-load.d
echo "nvidia" | sudo tee nvidia.conf > /dev/null
echo "nvidia_modeset" | sudo tee -a nvidia.conf > /dev/null
echo "nvidia_uvm" | sudo tee -a nvidia.conf > /dev/null
echo "nvidia_drm" | sudo tee -a nvidia.conf > /dev/null
cd ~

sudo mkinitcpio -P
sudo reboot
```

## B4. Use the GPU for LLMs and dev work

```bash
prime-run <app>
prime-run python my_llm.py
prime-run ollama run llama3
```

Check usage:

```bash
watch -n 1 nvidia-smi
```

## B5. Prevent Arch updates from breaking this

When you run `sudo pacman -Syu`, Arch will try to reinstall `nvidia-open-dkms`. To prevent this, add it to `IgnorePkg` in `/etc/pacman.conf`:

```bash
sudo sed -i '/^#IgnorePkg.*=/a IgnorePkg = nvidia-open-dkms nvidia-utils' /etc/pacman.conf
```

## B6. Update nvidia-580xx-dkms

The 580 branch is supported by NVIDIA for 3 years. Update it manually:

```bash
yay -Syu nvidia-580xx-dkms nvidia-580xx-utils
```

## B7. Recovery if boot fails

Boot from Arch live USB:

```bash
mount /dev/nvme0n1p2 /mnt    # adjust partition if different
arch-chroot /mnt
yay -Rns nvidia-580xx-dkms nvidia-580xx-utils nvidia-prime
# If yay unavailable:
# pacman -Rns nvidia-580xx-dkms nvidia-580xx-utils nvidia-prime
exit
umount -R /mnt
reboot
```

---

# Quick reference

| What | Where |
|---|---|
| Fingerprint source | `~/build/libfprint-sigfm` |
| NVIDIA switch script | `~/Desktop/switch-to-nvidia-580xx.sh` |
| Enrolled fingerprints | `/var/lib/fprint/<user>/` |
| libfprint installed at | `/usr/local/lib/libfprint-2.so` |
| spidev device | `/dev/spidev1.0` |
| Fingerprint sensor | `/sys/bus/spi/devices/spi-ELAN7001:00/` |

---

# Credits

- `mincrmatt12/elan-spi-fingerprint` — SPI protocol reverse engineering
- `goodix-fp-linux-dev/libfprint` (sigfm branch) — SIGFM matcher integration
- `r4nd3l/elan-3104-fingerprint-linux` — Investigation writeup
- Arch Linux NVIDIA 590 announcement — for Pascal migration to 580xx
