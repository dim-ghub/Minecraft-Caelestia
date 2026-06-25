#!/bin/bash

# Prevent running with sudo
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script with sudo. Run it normally." >&2
    exit 1
fi

if [ $# -ne 0 ]; then
    echo "usage: $(basename "$(realpath "$0")")" >&2
    exit 1
fi

POSTHOOKS_DIR="$HOME/.local/bin/posthooks"
THEME_DIR="$HOME/.local/state/caelestia/theme"
CLI_JSON="$HOME/.config/caelestia/cli.json"
POSTHOOK_CMD="$POSTHOOKS_DIR/minecraft.sh"

echo "Uninstalling..."

# Remove posthook files
rm -rf "$POSTHOOKS_DIR/minecraft/"
rm -rf "$POSTHOOKS_DIR/minecraft.sh"

# Remove theme directory
rm -rf "$THEME_DIR"

# Remove posthook from cli.json
if [[ -f "$CLI_JSON" ]]; then
    EXISTING_HOOK=$(jq -r '.wallpaper.postHook // empty' "$CLI_JSON" 2>/dev/null)
    if [[ -n "$EXISTING_HOOK" ]]; then
        # Remove our command from the hook
        NEW_HOOK=$(echo "$EXISTING_HOOK" | sed "s| && ${POSTHOOK_CMD}||g" | sed "s|${POSTHOOK_CMD} && ||g" | sed "s|${POSTHOOK_CMD}||g")
        if [[ -z "$NEW_HOOK" ]]; then
            # Remove the postHook key entirely if empty
            jq 'del(.wallpaper.postHook)' "$CLI_JSON" > "$CLI_JSON.tmp" && mv "$CLI_JSON.tmp" "$CLI_JSON"
        else
            jq --arg hook "$NEW_HOOK" '.wallpaper.postHook = $hook' "$CLI_JSON" > "$CLI_JSON.tmp" && mv "$CLI_JSON.tmp" "$CLI_JSON"
        fi
        echo "Removed minecraft posthook from cli.json"
    fi
fi

echo "Done!"
