#!/usr/bin/env bash
#
# Run a sort straight from the shell, without going through the panel menu.
# Handy for testing, for a global shortcut, or for scripting.
#
#   tools/sort.sh vertical|horizontal|optimal|cascade [--debug]
#
# SPDX-License-Identifier: GPL-2.0-or-later

set -euo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-optimal}"
debug="false"
[[ ${2:-} == "--debug" ]] && debug="true"

case "$mode" in
    vertical|horizontal|optimal|cascade) ;;
    *) printf 'Usage: %s vertical|horizontal|optimal|cascade [--debug]\n' "${0##*/}" >&2; exit 1 ;;
esac

lib="${PLASMA_WINDOW_SORTER_SCRIPT:-}"
for candidate in "$lib" /usr/share/plasma-window-sorter/sorter.js "$PROJECT_DIR/kwin/sorter.js"; do
    [[ -n $candidate && -f $candidate ]] && { lib="$candidate"; break; }
done
[[ -f ${lib:-} ]] || { echo "sorter.js not found" >&2; exit 1; }

qdbus="$(command -v qdbus6 || command -v qdbus)"
plugin="plasma-window-sorter-cli-$$"
script="${XDG_RUNTIME_DIR:-/tmp}/$plugin.js"

{
    printf 'var PWS_MODE = "%s";\n' "$mode"
    printf 'var PWS_OUTPUT_NAME = "";\nvar PWS_OUTPUT_RECT = null;\n'
    printf 'var PWS_INCLUDE_MINIMIZED = %s;\n' "$(kreadconfig6 --file plasma-window-sorterrc --group General --key IncludeMinimized --default false 2>/dev/null || echo false)"
    printf 'var PWS_TARGET_ASPECT = %s;\n' "$(kreadconfig6 --file plasma-window-sorterrc --group General --key TargetAspect --default 1.3333333 2>/dev/null || echo 1.3333333)"
    printf 'var PWS_DEBUG = %s;\n' "$debug"
    cat "$lib"
} > "$script"

"$qdbus" org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$script" "$plugin" >/dev/null
"$qdbus" org.kde.KWin /Scripting org.kde.kwin.Scripting.start
sleep 1
"$qdbus" org.kde.KWin /Scripting org.kde.kwin.Scripting.unloadScript "$plugin" >/dev/null 2>&1 || true
rm -f "$script"
