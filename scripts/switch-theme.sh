#!/usr/bin/env bash
# Switch the live terminal theme between amber and green.
# Usage: ./scripts/switch-theme.sh amber|green
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THEME="${1:-}"

case "$THEME" in
    amber|green) ;;
    *) echo "Usage: $(basename "$0") amber|green" >&2; exit 1 ;;
esac

install -m644 "$REPO_DIR/dotfiles/fish/config-$THEME.fish" "$HOME/.config/fish/config.fish"
install -m644 "$REPO_DIR/dotfiles/kitty/hacker-$THEME.conf" "$HOME/.config/kitty/hacker-$THEME.conf"
install -m644 "$REPO_DIR/dotfiles/starship/starship-$THEME.toml" "$HOME/.config/starship.toml"

KCFG="$HOME/.config/kitty/kitty.conf"
if grep -q '^include hacker-.*\.conf$' "$KCFG"; then
    sed -i "s|^include hacker-.*\.conf$|include hacker-$THEME.conf|" "$KCFG"
fi

if command -v atuin >/dev/null 2>&1; then
    touch "$HOME/.config/atuin/config.toml"
    if [[ "$THEME" == "amber" ]]; then
        atuin config set theme.name hacker-amber --type string >/dev/null
    else
        atuin config set theme.name default --type string >/dev/null
    fi
fi

ZCFG="$HOME/.config/zellij/config.kdl"
if [[ -f "$ZCFG" ]]; then
    sed -i '/^theme[[:space:]]/d' "$ZCFG"
    if [[ "$THEME" == "amber" ]]; then
        ZTHEME="gruvbox-dark"
    else
        ZTHEME="everforest-dark"
    fi
    printf '\ntheme "%s"\n' "$ZTHEME" >> "$ZCFG"
fi

kitty @ load-config >/dev/null 2>&1 || true

echo "Theme set to $THEME."
echo "Run: exec fish   (and restart zellij sessions for the new zellij theme)"
