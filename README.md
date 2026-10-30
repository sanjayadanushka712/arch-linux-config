# Arch Linux Config

Personal Arch Linux setup for an **ASUS VivoBook X512JP** (Intel Iris Plus G7 +
NVIDIA MX330) running **KDE Plasma** and **Hyprland / Caelestia**.

This repo restores the terminal stack, desktop configs, and a few hardware
tweaks after a fresh Arch install.

## What is inside

- **Terminal:** kitty, fish, starship, zellij, atuin, fzf, yazi, carapace
- **CLI tools:** mise, just, television (`tv`), dust, procs, sd, broot
- **Desktop:** KDE Plasma configs, Hyprland/Caelestia, foot, fuzzel, btop,
  fastfetch, cava, GTK, fonts, XDG defaults
- **Themes:** amber (default) and green, switchable at any time
- **System:** 65% battery charge limit, NVIDIA 580xx switch script, ASUS notes
- **Apps:** VS Code profile exports

## Quick start

Assumes Arch is already installed, you can log in, and you have network access.

```bash
git clone <your-repo-url> ~/Desktop/arch-linux-config
cd ~/Desktop/arch-linux-config
./bootstrap.sh --dry-run     # review first
./bootstrap.sh
exec fish
```

`bootstrap.sh` asks for sudo when needed. It never stores your password.

### Choose what runs

```bash
./bootstrap.sh --packages     # pacman + AUR packages only
./bootstrap.sh --dotfiles     # configs only
./bootstrap.sh --battery      # 65% charge limit service only
./bootstrap.sh --vscode       # copy profile exports only
./bootstrap.sh --green        # use the green theme
./bootstrap.sh --amber        # use the amber theme (default)
./bootstrap.sh --dry-run      # print actions, change nothing
```

With no section flag it runs all four sections. Existing configs are backed up
to `~/.config-backup-<timestamp>/` before being replaced.

### Desktop environment (optional)

The bootstrap installs terminal packages only. Pick a desktop first:

```bash
# KDE Plasma
sudo pacman -S --needed - < packages/desktop-kde.txt
yay -S --needed darkly-bin

# or Hyprland + Caelestia
sudo pacman -S --needed - < packages/desktop-hypr.txt
yay -S --needed caelestia-shell caelestia-cli caelestia-firefox-theme

sudo systemctl enable sddm
```

Then run the dotfiles section and reboot.

## Manual steps

### NVIDIA (Pascal needs the 580xx branch)

The MX330 is Pascal, so the current open driver does not support it.

```bash
./system/nvidia/switch-to-nvidia-580xx.sh
```

Read `docs/asus-x512jp-setup-guide.md` (Part B) first. It explains the driver
packages, `nvidia-prime`, and the kernel parameter checks.

### Fingerprint reader

The exact steps and caveats are in `docs/asus-x512jp-setup-guide.md` (Part A).
This is not automated because it depends on the enrolled user and PAM setup.

### Battery charge limit

`system/battery-charge-limit.service` writes `65` to
`/sys/class/power_supply/BAT0/charge_control_end_threshold` at boot. The
bootstrap installs it only when that path exists.

```bash
cat /sys/class/power_supply/BAT0/charge_control_end_threshold
```

### VS Code

Profiles are copied to `~/.local/share/vscode-profiles/`.

Import with **Profiles -> ... -> Import Profile**:
`devops.code-profile`, `mobile.code-profile`, `web.code-profile`.

## Themes

```bash
./scripts/switch-theme.sh amber
./scripts/switch-theme.sh green
```

The script updates fish, kitty, starship, atuin, and zellij. Then:

```bash
exec fish
# restart kitty or run: kitty @ load-config
# restart zellij sessions to apply the zellij theme
```

## Repository layout

```text
bootstrap.sh                 main installer
packages/
  terminal.txt               packages installed by bootstrap.sh
  desktop-kde.txt            optional KDE packages
  desktop-hypr.txt           optional Hyprland/Caelestia packages
  pacman-explicit-reference.txt  snapshot of this machine (reference only)
  aur-reference.txt          AUR packages on this machine (reference only)
dotfiles/
  fish/                      config-amber.fish, config-green.fish, functions
  kitty/                     kitty.conf + hacker-amber/green.conf
  starship/                  starship-amber.toml, starship-green.toml
  atuin/                     config.toml + hacker-amber theme
  zellij/                    config.kdl (theme patched by bootstrap)
  foot/ fuzzel/ btop/ fastfetch/ cava/
  hypr/ caelestia/           Wayland desktop
  kde/                       curated Plasma configs
  gtk/ xdg/                  GTK, fonts, mimeapps, user dirs
  environment.d/             nvidia + ollama environment
  bash/ git/                 shell and git configs
system/
  battery-charge-limit.service
  nvidia/                    switch-to-nvidia-580xx.sh, nvidia-settings-rc
apps/vscode/                 VS Code profile exports
docs/                        ASUS guide + small system notes
scripts/switch-theme.sh
```

## Notes

- `packages/pacman-explicit-reference.txt` is a full snapshot for reference.
  Installing every line is heavy and includes unrelated apps; only
  `packages/terminal.txt` is used by the bootstrap.
- No secrets, browser profiles, SSH keys, or credential files are stored here.
  `~/.gitconfig` points to `~/.git-credentials-neoarch`, so run `gh auth login`
  and `git config --global credential.helper 'store --file ~/.git-credentials-neoarch'`
  after restoring.
- `dotfiles/kde/plasma-org.kde.plasma.desktop-appletsrc` is intentionally not
  stored because it contains personal desktop file names.
- Zellij's config is patched by appending `theme "..."` at the end of
  `~/.config/zellij/config.kdl`, which overrides earlier values.
- The KDE lock screen config points at
  `~/Pictures/Wallpapers/light-2.png`; wallpapers are not included in this repo.
- To stop the fingerprint reader from being asked for terminal sudo, see
  `docs/usefulthings.txt`.

## Troubleshooting

- **`carapace` not found:** install `carapace-bin` and restart the shell.
- **yay cannot ask for sudo:** run `yay -S carapace-bin` in a normal terminal,
  or build it with `makepkg -si` and install the `.pkg.tar.zst` with
  `sudo pacman -U`.
- **kitty theme did not change:** restart kitty. `kitty @ load-config` needs
  remote control enabled.
- **zellij theme did not change:** start a new zellij session.
- **atuin theme missing:** `atuin config set theme.name hacker-amber`.
