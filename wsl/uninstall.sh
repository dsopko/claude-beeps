#!/usr/bin/env bash
# claude-beeps uninstaller (WSL / bash)
#
# Removes ONLY the hook groups whose command references our scripts
# (notify.sh, start.sh, stop.sh). Leaves every other hook group and
# every other settings key untouched. Safe to run multiple times.
#
# Requires: jq
# Run: bash ./uninstall.sh

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
HOOKS_DIR="$HOME/.claude/hooks"

if [ ! -f "$SETTINGS" ]; then
    echo "No settings.json at $SETTINGS - nothing to uninstall."
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required. Install with: sudo apt install -y jq"
    exit 1
fi

STAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="$SETTINGS.bak-uninstall-$STAMP"
cp "$SETTINGS" "$BACKUP"
echo "Backed up settings.json -> $BACKUP"

# jq filter:
#   For each of our target events, filter its hook groups to keep only those
#   whose inner hooks[].command does NOT reference any of our script names.
#   If the resulting array is empty, remove the event key entirely.
#   If the whole .hooks object ends up empty, remove it too.
tmp=$(mktemp)
jq '
    def is_ours(g):
      (g.hooks // []) | any(
        .type == "command"
        and (.command // "" | test("notify\\.sh|start\\.sh|stop\\.sh"))
      );

    def clean_event(e):
      (.hooks[e] // []) as $orig
      | ($orig | map(select(is_ours(.) | not))) as $kept
      | if ($kept | length) == 0 then del(.hooks[e])
        else .hooks[e] = $kept end;

    clean_event("Notification")
    | clean_event("PermissionRequest")
    | clean_event("UserPromptSubmit")
    | clean_event("Stop")
    | if (.hooks // {} | length) == 0 then del(.hooks) else . end
' "$SETTINGS" > "$tmp"

# Validate before overwriting
if ! jq empty "$tmp" >/dev/null 2>&1; then
    echo "ERROR: filtered output failed to parse. Restoring backup."
    rm -f "$tmp"
    exit 1
fi

mv "$tmp" "$SETTINGS"
echo "settings.json updated and validated."

# Delete our scripts and log
for f in notify.sh start.sh stop.sh notify.log; do
    p="$HOOKS_DIR/$f"
    if [ -e "$p" ]; then
        rm -f "$p"
        echo "Deleted $p"
    fi
done

# Best-effort: remove any leftover start-<session>.txt timestamps
for f in "$HOOKS_DIR"/start-*.txt; do
    [ -e "$f" ] || continue
    rm -f "$f"
    echo "Deleted $f"
done

echo ""
echo "Done. Restart Claude Code (or run /hooks once) so the change takes effect."
echo "Backup preserved at: $BACKUP"
