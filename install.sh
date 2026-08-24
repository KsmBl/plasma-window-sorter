#!/usr/bin/env bash
#
# plasma-window-sorter - build and install the patched panel containment
#
# Replaces /usr/lib/qt6/plugins/plasma/applets/org.kde.panel.so with a build of
# the same upstream QML plus a Containment subclass that adds the window
# sorting entries to the panel's context menu. The original is backed up first.
#
# SPDX-License-Identifier: GPL-2.0-or-later

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
STAGE_DIR="$BUILD_DIR/stage"
DATA_DIR="/usr/share/plasma-window-sorter"
BACKUP_DIR="/var/lib/plasma-window-sorter"
HOOK_FILE="/etc/pacman.d/hooks/95-plasma-window-sorter.hook"
MARKER="plasma-window-sorter "
UPSTREAM_URL="https://invent.kde.org/plasma/plasma-desktop/-/raw"
API_URL="https://invent.kde.org/api/v4/projects/plasma%2Fplasma-desktop/repository/tree"
SKIP_FILES=("CMakeLists.txt" "Messages.sh")

restart_shell=1
install_hook=1
allow_download=1
include_minimized=""
debug_log=""
target_aspect=""

msg()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m::\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m::\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: ${0##*/} [options]

  --no-restart        Do not restart plasmashell at the end
  --no-hook           Do not install the pacman upgrade-warning hook
  --offline           Never download upstream QML, use the vendored copy
  --include-minimized Also un-minimize and tile minimized windows
  --debug             Log every sort to the journal (kwin_wayland)
  --aspect <ratio>    Preferred cell aspect for "Optimal" (default 1.3333)
  -h, --help          This text

The panel plugin is a system file: you will be asked for your sudo password.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-restart) restart_shell=0 ;;
        --no-hook) install_hook=0 ;;
        --offline) allow_download=0 ;;
        --include-minimized) include_minimized="true" ;;
        --debug) debug_log="true" ;;
        --aspect) target_aspect="${2:-}"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
    shift
done

[[ $EUID -ne 0 ]] || die "run this as your normal user - it calls sudo where it needs to."
command -v pacman >/dev/null || die "this installer targets Arch Linux (pacman not found)."
command -v plasmashell >/dev/null || die "plasmashell not found - is Plasma installed?"

# --- locate the file we are going to replace ---------------------------------
TARGET_SO="/usr/lib/qt6/plugins/plasma/applets/org.kde.panel.so"
if [[ ! -f $TARGET_SO ]]; then
    TARGET_SO="$(pacman -Ql plasma-desktop 2>/dev/null | awk '/org\.kde\.panel\.so$/ {print $2; exit}')"
    [[ -n $TARGET_SO && -f $TARGET_SO ]] || die "cannot find the installed org.kde.panel.so."
fi
msg "Panel plugin: $TARGET_SO"

PLASMA_VERSION="$(plasmashell --version | awk '{print $NF}')"
msg "Plasma version: $PLASMA_VERSION"

# --- upstream QML matching the installed Plasma ------------------------------
UPSTREAM_DIR="$PROJECT_DIR/upstream/$PLASMA_VERSION"

fetch_upstream() {
    local dir="$1" version="$2" tmp files file
    command -v curl >/dev/null || return 1
    tmp="$(mktemp -d)"

    files="$(curl -sfL --max-time 30 "$API_URL?ref=v$version&path=containments/panel&per_page=100" \
             | python3 -c 'import json,sys
try:
    for entry in json.load(sys.stdin):
        if entry.get("type") == "blob":
            print(entry["name"])
except Exception:
    pass' 2>/dev/null || true)"

    if [[ -z $files ]]; then
        # API unreachable: fall back to the file set we know about
        files=$'main.qml\nAppletContainer.qml\nConfigOverlay.qml\nLayoutManager.js\nmain.xml\nmetadata.json'
    fi

    while read -r file; do
        [[ -n $file ]] || continue
        local skip=0
        for s in "${SKIP_FILES[@]}"; do [[ $file == "$s" ]] && skip=1; done
        (( skip )) && continue
        curl -sfL --max-time 30 "$UPSTREAM_URL/v$version/containments/panel/$file" -o "$tmp/$file" || { rm -rf "$tmp"; return 1; }
    done <<< "$files"

    [[ -f $tmp/main.qml && -f $tmp/metadata.json ]] || { rm -rf "$tmp"; return 1; }
    mkdir -p "$dir"
    cp -f "$tmp"/* "$dir"/
    rm -rf "$tmp"
    return 0
}

if [[ ! -f $UPSTREAM_DIR/main.qml ]]; then
    if (( allow_download )); then
        msg "Fetching the panel sources for $PLASMA_VERSION from invent.kde.org ..."
        fetch_upstream "$UPSTREAM_DIR" "$PLASMA_VERSION" || warn "download failed."
    fi
fi

if [[ ! -f $UPSTREAM_DIR/main.qml ]]; then
    UPSTREAM_DIR="$(find "$PROJECT_DIR/upstream" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1)"
    [[ -n ${UPSTREAM_DIR:-} && -f $UPSTREAM_DIR/main.qml ]] || die "no panel QML available (nothing vendored, nothing downloaded)."
    warn "Using vendored QML from ${UPSTREAM_DIR##*/} for Plasma $PLASMA_VERSION."
    warn "If the panel misbehaves, run uninstall.sh and report the version mismatch."
fi
msg "Panel QML: ${UPSTREAM_DIR##*/}"

# --- build dependencies ------------------------------------------------------
missing=()
for pkg in extra-cmake-modules cmake ninja gcc; do
    pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if (( ${#missing[@]} )); then
    msg "Installing build dependencies: ${missing[*]}"
    sudo pacman -S --needed --noconfirm "${missing[@]}"
fi

# --- build -------------------------------------------------------------------
msg "Staging sources ..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp "$UPSTREAM_DIR"/* "$STAGE_DIR"/
for s in "${SKIP_FILES[@]}"; do rm -f "$STAGE_DIR/$s"; done
cp "$PROJECT_DIR/src/CMakeLists.txt" "$PROJECT_DIR/src/panelsorter.cpp" "$PROJECT_DIR/src/panelsorter.h" "$STAGE_DIR"/

msg "Building ..."
BUILD_LOG="$BUILD_DIR/build.log"
: > "$BUILD_LOG"
if ! cmake -S "$STAGE_DIR" -B "$BUILD_DIR/cmake" -G Ninja \
           -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr >>"$BUILD_LOG" 2>&1; then
    tail -25 "$BUILD_LOG" >&2
    die "cmake configure failed (full log: $BUILD_LOG)"
fi
if ! cmake --build "$BUILD_DIR/cmake" >>"$BUILD_LOG" 2>&1; then
    tail -25 "$BUILD_LOG" >&2
    die "build failed (full log: $BUILD_LOG)"
fi

BUILT_SO="$(find "$BUILD_DIR/cmake" -name 'org.kde.panel.so' -type f | head -1)"
[[ -n $BUILT_SO ]] || die "build produced no org.kde.panel.so."
grep -aq "$MARKER" "$BUILT_SO" || die "built plugin lacks the build marker - refusing to install it."
msg "Built $BUILT_SO"

# --- back up the distribution's panel ----------------------------------------
sudo mkdir -p "$BACKUP_DIR" "$DATA_DIR"
if grep -aq "$MARKER" "$TARGET_SO"; then
    msg "Installed panel is already ours - keeping the existing backup."
else
    msg "Backing up the stock panel to $BACKUP_DIR/org.kde.panel.so.orig"
    sudo cp -a "$TARGET_SO" "$BACKUP_DIR/org.kde.panel.so.orig"
    pacman -Q plasma-desktop 2>/dev/null | sudo tee "$BACKUP_DIR/origin" >/dev/null
    printf '%s\n' "$TARGET_SO" | sudo tee "$BACKUP_DIR/target" >/dev/null
fi

# --- install -----------------------------------------------------------------
# Never write into the file the running plasmashell has mapped: overwriting it
# in place corrupts its code pages and it segfaults on the way out. Install to a
# temporary name next to it and rename, which swaps the inode atomically.
msg "Installing the patched panel and the KWin payload ..."
TMP_SO="$(dirname "$TARGET_SO")/.org.kde.panel.so.pws-incoming"
sudo install -Dm755 "$BUILT_SO" "$TMP_SO"
sudo mv -f "$TMP_SO" "$TARGET_SO"
sudo install -Dm644 "$PROJECT_DIR/kwin/sorter.js" "$DATA_DIR/sorter.js"

# Behaviour lives in a plain config file, so it can be changed without rebuilding.
if [[ -n $include_minimized ]]; then
    kwriteconfig6 --file plasma-window-sorterrc --group General --key IncludeMinimized true
fi
if [[ -n $debug_log ]]; then
    kwriteconfig6 --file plasma-window-sorterrc --group General --key Debug true
fi
if [[ -n $target_aspect ]]; then
    kwriteconfig6 --file plasma-window-sorterrc --group General --key TargetAspect "$target_aspect"
fi

# --- pacman hook: an upgrade of plasma-desktop puts the stock panel back ------
if (( install_hook )); then
    sudo install -d /etc/pacman.d/hooks
    sudo tee "$HOOK_FILE" >/dev/null <<EOF
# Installed by plasma-window-sorter
[Trigger]
Operation = Upgrade
Type = Package
Target = plasma-desktop

[Action]
Description = plasma-window-sorter: panel replaced by the upgrade
When = PostTransaction
Exec = /usr/bin/bash -c 'printf "\n>> plasma-desktop was upgraded, so the stock panel is back.\n>> Re-run %s to restore window sorting.\n\n" "$PROJECT_DIR/install.sh"'
EOF
    msg "Pacman hook installed at $HOOK_FILE"
fi

# --- drop any development copy that would shadow the system plugin -----------
USER_PLUGIN="$HOME/.local/lib/qt6/plugins/plasma/applets/org.kde.panel.so"
if [[ -f $USER_PLUGIN ]]; then
    msg "Removing the development copy at $USER_PLUGIN"
    rm -f "$USER_PLUGIN"
fi
if systemctl --user show-environment 2>/dev/null | grep -qx "QT_PLUGIN_PATH=$HOME/.local/lib/qt6/plugins"; then
    systemctl --user unset-environment QT_PLUGIN_PATH
fi
rm -f "$HOME/.local/share/plasma-window-sorter/sorter.js"

# --- restart the shell -------------------------------------------------------
if (( restart_shell )); then
    msg "Restarting plasmashell ..."
    if systemctl --user is-active --quiet plasma-plasmashell.service; then
        systemctl --user restart plasma-plasmashell.service
    else
        kquitapp6 plasmashell 2>/dev/null || true
        sleep 1
        setsid plasmashell >/dev/null 2>&1 &
    fi
    sleep 4
fi

cat <<EOF

$(msg "Done.")
Right-click an empty spot on the panel - next to "Show Panel Configuration"
you now have:

    Sort Windows Vertically      full-width rows
    Sort Windows Horizontally    full-height columns
    Sort Windows Optimally       even grid
    Sort Windows Cascading       one offset pile, equal sizes

To undo everything: $PROJECT_DIR/uninstall.sh
EOF
