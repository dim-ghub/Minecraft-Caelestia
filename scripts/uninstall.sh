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

PREFIX="${PREFIX:-$HOME/.local}"
POSTHOOKS_DIR="$PREFIX/bin/posthooks"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
THEME_DIR="$XDG_STATE_HOME/caelestia/theme"
CLI_JSON="$XDG_CONFIG_HOME/caelestia/cli.json"
POSTHOOK_CMD="$POSTHOOKS_DIR/minecraft.sh"

echo "Uninstalling..."

# Remove posthook files
rm -rf "$POSTHOOKS_DIR/minecraft/"
rm -rf "$POSTHOOKS_DIR/minecraft.sh"

# Remove theme directory
rm -rf "$THEME_DIR"

# Remove posthook from cli.json
if [[ -f "$CLI_JSON" ]]; then
    remove_posthook() {
        local key="$1"
        local existing
        existing=$(jq -r --arg k "$key" '.[$k].postHook // empty' "$CLI_JSON" 2>/dev/null)
        [[ -z "$existing" ]] && return

        NEW_HOOK=$(echo "$existing" | sed "s| && ${POSTHOOK_CMD}||g" | sed "s|${POSTHOOK_CMD} && ||g" | sed "s|${POSTHOOK_CMD}||g")
        if [[ -z "$NEW_HOOK" ]]; then
            jq --arg key "$key" 'del(.[$key].postHook)' "$CLI_JSON" > "$CLI_JSON.tmp" && mv "$CLI_JSON.tmp" "$CLI_JSON"
        else
            jq --arg key "$key" --arg hook "$NEW_HOOK" '.[$key].postHook = $hook' "$CLI_JSON" > "$CLI_JSON.tmp" && mv "$CLI_JSON.tmp" "$CLI_JSON"
        fi
        echo "Removed minecraft posthook from $key.postHook"
    }

    remove_posthook "wallpaper"
    remove_posthook "theme"
fi

echo "Done!"
