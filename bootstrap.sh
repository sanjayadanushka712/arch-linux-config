#!/usr/bin/env bash
# Arch Linux config bootstrap for the ASUS VivoBook X512JP setup.
# Installs packages + restores dotfiles. System tweaks are opt-in.
#
# Usage:
#   ./bootstrap.sh              # packages + dotfiles + battery + vscode profiles
#   ./bootstrap.sh --packages
#   ./bootstrap.sh --dotfiles
#   ./bootstrap.sh --battery
#   ./bootstrap.sh --vscode
#   ./bootstrap.sh --green      # use the green theme (default: amber)
#   ./bootstrap.sh --dry-run    # show what would happen
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="amber"
DRY_RUN=0
RUN_PACKAGES=0
RUN_DOTFILES=0
RUN_BATTERY=0
RUN_VSCODE=0

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Sections (no section = all):
  --packages      install pacman/AUR packages
  --dotfiles      back up + copy configs
  --battery       install the 65% battery charge limit service
  --vscode        copy VS Code profile exports for import

Options:
  --amber         amber theme (default)
  --green         green theme
  --dry-run       print actions without changing anything
  -h, --help      show this help

NVIDIA and fingerprint setup are manual; see docs/ after running this.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --packages) RUN_PACKAGES=1 ;;
        --dotfiles) RUN_DOTFILES=1 ;;
        --battery) RUN_BATTERY=1 ;;
        --vscode) RUN_VSCODE=1 ;;
        --amber) THEME="amber" ;;
        --green) THEME="green" ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

if [[ $RUN_PACKAGES -eq 0 && $RUN_DOTFILES -eq 0 && $RUN_BATTERY -eq 0 && $RUN_VSCODE -eq 0 ]]; then
    RUN_PACKAGES=1
    RUN_DOTFILES=1
    RUN_BATTERY=1
    RUN_VSCODE=1
fi

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not as root." >&2
    exit 1
fi

if ! command -v pacman >/dev/null 2>&1; then
    echo "This bootstrap targets Arch Linux (pacman not found)." >&2
    exit 1
fi

if [[ $DRY_RUN -eq 0 && ( $RUN_PACKAGES -eq 1 || $RUN_BATTERY -eq 1 ) ]]; then
    echo "==> Requesting sudo"
    sudo -v
fi

# ---------------------------------------------------------------- helpers
run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  [dry] $*"
    else
        "$@"
    fi
}

BK="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

backup_path() {
    local src="$1"
    [[ -e "$src" ]] || return 0
    local rel="${src#"$HOME"/}"
    echo "    backup: $rel"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$BK/$(dirname "$rel")"
        cp -a "$src" "$BK/$rel"
    fi
}

copy_file() {
    local src="$1" dest="$2" mode="${3:-644}"
    echo "  $src -> $dest"
    backup_path "$dest"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$(dirname "$dest")"
        install -m "$mode" "$src" "$dest"
    fi
}

copy_dir() {
    local src="$1" dest="$2"
    echo "  $src/ -> $dest/"
    backup_path "$dest"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$dest"
        cp -a "$src/." "$dest/"
    fi
}

# ---------------------------------------------------------------- packages
install_packages() {
    echo "==> Installing packages"
    mapfile -t PKGS < <(grep -vE '^[[:space:]]*(#|$)' "$REPO_DIR/packages/terminal.txt")
    run sudo pacman -S --needed --noconfirm "${PKGS[@]}"

    if ! command -v carapace >/dev/null 2>&1; then
        echo "==> Installing carapace-bin (AUR)"
        if command -v yay >/dev/null 2>&1; then
            run yay -S --needed --noconfirm --answerclean None --answerdiff None carapace-bin
        elif [[ $DRY_RUN -eq 1 ]]; then
            echo "  [dry] git clone aur/carapace-bin + makepkg -si"
        else
            local tmp
            tmp="$(mktemp -d)"
            git clone --depth 1 https://aur.archlinux.org/carapace-bin.git "$tmp/carapace-bin"
            (cd "$tmp/carapace-bin" && makepkg -si --noconfirm)
            rm -rf "$tmp"
        fi
    fi
}

# ---------------------------------------------------------------- dotfiles
install_dotfiles() {
    echo "==> Restoring dotfiles ($THEME theme)"

    copy_file "$REPO_DIR/dotfiles/fish/config-$THEME.fish" "$HOME/.config/fish/config.fish"
    copy_dir "$REPO_DIR/dotfiles/fish/functions" "$HOME/.config/fish/functions"

    copy_file "$REPO_DIR/dotfiles/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
    for t in amber green; do
        copy_file "$REPO_DIR/dotfiles/kitty/hacker-$t.conf" "$HOME/.config/kitty/hacker-$t.conf"
    done
    local kcfg="$HOME/.config/kitty/kitty.conf"
    if [[ $DRY_RUN -eq 0 ]]; then
        if grep -q '^include hacker-.*\.conf$' "$kcfg"; then
            sed -i "s|^include hacker-.*\.conf$|include hacker-$THEME.conf|" "$kcfg"
        else
            printf '\ninclude hacker-%s.conf\n' "$THEME" >> "$kcfg"
        fi
    else
        echo "  kitty include -> hacker-$THEME.conf"
    fi

    copy_file "$REPO_DIR/dotfiles/starship/starship-$THEME.toml" "$HOME/.config/starship.toml"

    copy_file "$REPO_DIR/dotfiles/atuin/config.toml" "$HOME/.config/atuin/config.toml"
    copy_file "$REPO_DIR/dotfiles/atuin/themes/hacker-amber.toml" "$HOME/.config/atuin/themes/hacker-amber.toml"
    if command -v atuin >/dev/null 2>&1 && [[ $DRY_RUN -eq 0 ]]; then
        if [[ "$THEME" == "amber" ]]; then
            atuin config set theme.name hacker-amber --type string >/dev/null
        else
            atuin config set theme.name default --type string >/dev/null
        fi
    fi

    local zcfg="$HOME/.config/zellij/config.kdl"
    local ztheme="gruvbox-dark"
    [[ "$THEME" == "green" ]] && ztheme="everforest-dark"
    copy_file "$REPO_DIR/dotfiles/zellij/config.kdl" "$zcfg"
    if [[ $DRY_RUN -eq 0 ]]; then
        sed -i '/^theme[[:space:]]/d' "$zcfg"
        printf '\ntheme "%s"\n' "$ztheme" >> "$zcfg"
    else
        echo "  zellij theme -> $ztheme"
    fi

    # desktop / Wayland
    copy_file "$REPO_DIR/dotfiles/foot/foot.ini" "$HOME/.config/foot/foot.ini"
    copy_file "$REPO_DIR/dotfiles/fuzzel/fuzzel.ini" "$HOME/.config/fuzzel/fuzzel.ini"
    copy_file "$REPO_DIR/dotfiles/btop/btop.conf" "$HOME/.config/btop/btop.conf"
    copy_file "$REPO_DIR/dotfiles/btop/caelestia-theme/caelestia.theme" "$HOME/.config/btop/themes/caelestia.theme"
    copy_file "$REPO_DIR/dotfiles/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    copy_file "$REPO_DIR/dotfiles/cava/config" "$HOME/.config/cava/config"
    copy_dir "$REPO_DIR/dotfiles/hypr" "$HOME/.config/hypr"
    copy_dir "$REPO_DIR/dotfiles/caelestia" "$HOME/.config/caelestia"

    copy_file "$REPO_DIR/dotfiles/environment.d/nvidia.conf" "$HOME/.config/environment.d/nvidia.conf"
    copy_file "$REPO_DIR/dotfiles/environment.d/ollama.conf" "$HOME/.config/environment.d/ollama.conf"

    # KDE Plasma
    local f
    for f in "$REPO_DIR"/dotfiles/kde/*; do
        [[ -f "$f" ]] || continue
        copy_file "$f" "$HOME/.config/$(basename "$f")"
    done

    # GTK / fonts / XDG
    copy_file "$REPO_DIR/dotfiles/gtk/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini" 600
    copy_file "$REPO_DIR/dotfiles/gtk/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" 600
    copy_file "$REPO_DIR/dotfiles/gtk/gtkrc-2.0" "$HOME/.gtkrc-2.0"
    copy_file "$REPO_DIR/dotfiles/gtk/fonts.conf" "$HOME/.fonts.conf"
    copy_file "$REPO_DIR/dotfiles/xdg/mimeapps.list" "$HOME/.config/mimeapps.list"
    copy_file "$REPO_DIR/dotfiles/xdg/user-dirs.dirs" "$HOME/.config/user-dirs.dirs" 600

    # shell + git
    copy_file "$REPO_DIR/dotfiles/bash/bashrc" "$HOME/.bashrc"
    copy_file "$REPO_DIR/dotfiles/bash/bash_profile" "$HOME/.bash_profile"
    copy_file "$REPO_DIR/dotfiles/bash/profile" "$HOME/.profile"
    copy_file "$REPO_DIR/dotfiles/git/gitconfig" "$HOME/.gitconfig"

    if [[ $DRY_RUN -eq 0 ]]; then
        kitty @ load-config >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------- battery
install_battery() {
    local sysfs="/sys/class/power_supply/BAT0/charge_control_end_threshold"
    echo "==> Battery charge limit"
    if [[ ! -e "$sysfs" ]]; then
        echo "    skipped: $sysfs not found on this machine"
        return 0
    fi
    run sudo install -m644 "$REPO_DIR/system/battery-charge-limit.service" \
        /etc/systemd/system/battery-charge-limit.service
    run sudo systemctl daemon-reload
    run sudo systemctl enable --now battery-charge-limit.service
    if [[ $DRY_RUN -eq 0 ]]; then
        echo "    current limit: $(cat "$sysfs")%"
    fi
}

# ---------------------------------------------------------------- vscode
install_vscode() {
    local dest="$HOME/.local/share/vscode-profiles"
    echo "==> VS Code profiles"
    if [[ $DRY_RUN -eq 0 ]]; then
        mkdir -p "$dest"
        cp -a "$REPO_DIR/apps/vscode/"*.code-profile "$dest/"
        echo "    copied to $dest"
        echo "    Import: VS Code -> Profiles -> ... -> Import Profile"
    else
        echo "  [dry] copy *.code-profile -> $dest"
    fi
}

# ---------------------------------------------------------------- main
[[ $RUN_PACKAGES -eq 1 ]] && install_packages
[[ $RUN_DOTFILES -eq 1 ]] && install_dotfiles
[[ $RUN_BATTERY -eq 1 ]] && install_battery
[[ $RUN_VSCODE -eq 1 ]] && install_vscode

cat <<EOF

Done.

Next:
  exec fish                 # load shell colors, prompt, abbreviations
  kitty @ load-config       # already done if kitty was running
  restart zellij sessions   # apply the zellij theme

Theme: $THEME
Switch later:
  $REPO_DIR/scripts/switch-theme.sh green
  $REPO_DIR/scripts/switch-theme.sh amber

Manual steps still available:
  NVIDIA (Pascal / 580xx):  $REPO_DIR/system/nvidia/switch-to-nvidia-580xx.sh
  ASUS setup guide:         $REPO_DIR/docs/asus-x512jp-setup-guide.md
  Small system notes:       $REPO_DIR/docs/usefulthings.txt

Backups (if dotfiles were restored): $BK
EOF
