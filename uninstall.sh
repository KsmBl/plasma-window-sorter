#!/usr/bin/env bash
#
# plasma-window-sorter - put Plasma's own panel back
#
# SPDX-License-Identifier: GPL-2.0-or-later

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="/usr/share/plasma-window-sorter"
BACKUP_DIR="/var/lib/plasma-window-sorter"
HOOK_FILE="/etc/pacman.d/hooks/95-plasma-window-sorter.hook"
MARKER="plasma-window-sorter "

restart_shell=1
purge_config=0

msg()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-restart) restart_shell=0 ;;
        --purge) purge_config=1 ;;
        -h|--help)
            printf 'Usage: %s [--no-restart] [--purge]\n\n  --purge  also delete ~/.config/plasma-window-sorterrc\n' "${0##*/}"
            exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || die "run this as your normal user - it calls sudo where it needs to."

TARGET_SO="/usr/lib/qt6/plugins/plasma/applets/org.kde.panel.so"
[[ -f $BACKUP_DIR/target ]] && TARGET_SO="$(cat "$BACKUP_DIR/target")"

if [[ -f $TARGET_SO ]] && ! grep -aq "$MARKER" "$TARGET_SO"; then
    msg "The installed panel is already the distribution's own."
elif [[ -f $BACKUP_DIR/org.kde.panel.so.orig ]]; then
    msg "Restoring the stock panel from $BACKUP_DIR/org.kde.panel.so.orig"
    # Rename into place rather than overwriting the file plasmashell has mapped.
    TMP_SO="$(dirname "$TARGET_SO")/.org.kde.panel.so.pws-incoming"
    sudo install -Dm755 "$BACKUP_DIR/org.kde.panel.so.orig" "$TMP_SO"
    sudo mv -f "$TMP_SO" "$TARGET_SO"
else
    warn "No backup found - reinstalling plasma-desktop instead."
    sudo pacman -S --noconfirm plasma-desktop || die "could not restore the panel; run: sudo pacman -S plasma-desktop"
fi

msg "Removing our files ..."
sudo rm -rf "$DATA_DIR" "$BACKUP_DIR"
sudo rm -f "$HOOK_FILE"
rm -f "$HOME/.local/lib/qt6/plugins/plasma/applets/org.kde.panel.so"
rm -f "$HOME/.local/share/plasma-window-sorter/sorter.js"
(( purge_config )) && rm -f "$HOME/.config/plasma-window-sorterrc"

if (( restart_shell )); then
    msg "Restarting plasmashell ..."
    if systemctl --user is-active --quiet plasma-plasmashell.service; then
        systemctl --user restart plasma-plasmashell.service
    else
        kquitapp6 plasmashell 2>/dev/null || true
        sleep 1
        setsid plasmashell >/dev/null 2>&1 &
    fi
    sleep 3
fi

msg "Done - the panel is back to stock. ($PROJECT_DIR is untouched.)"
