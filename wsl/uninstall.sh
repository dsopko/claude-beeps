#!/usr/bin/env bash
# claude-beeps uninstaller (WSL / bash)
#
# Removes ONLY the hook groups whose command references our scripts,
# and only when the command path resolves inside ~/.claude/hooks/.
# The jq filter is anchored to \.claude/hooks/(notify|start|stop)\.sh
# so third-party hooks whose command merely ends with notify.sh, start.sh,
# or stop.sh (e.g. restart.sh, slack-notify.sh) are never touched.
# Leaves every other hook group and every other settings key untouched.
# Safe to run multiple times.
#
# Requires: jq
# Run: bash ./uninstall.sh

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
HOOKS_DIR="$HOME/.claude/hooks"
PATTERN='\.claude/hooks/(notify|start|stop)\.sh'
EVENTS='Notification PermissionRequest UserPromptSubmit Stop'

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

# First pass: list each hook group about to be removed with its command
# and event name, so the removal is never silent.
for evt in $EVENTS; do
    jq -r --arg evt "$evt" --arg pat "$PATTERN" '
        def is_ours(g):
          (g.hooks // []) | any(
            .type == "command"
            and (.command // "" | test($pat))
          );

        (.hooks[$evt] // [])
        | map(select(is_ours(.)))
        | .[]
        | (.hooks[] | select(.type == "command") | "Removing " + $evt + " hook group: " + .command)
    ' "$SETTINGS"
done

# Second pass: rewrite the settings with the matching groups removed.
tmp=$(mktemp)
jq --arg pat "$PATTERN" '
    def is_ours(g):
      (g.hooks // []) | any(
        .type == "command"
        and (.command // "" | test($pat))
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
echo "Done. The removal normally takes effect within seconds."
echo "If the beeps outlive it, run /hooks once (dismiss the dialog) or restart Claude Code."
echo "Backup preserved at: $BACKUP"
