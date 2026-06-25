#!/bin/bash

if [ $# -eq 0 ]; then
    echo "usage: $(basename "$(realpath "$0")") <dir> [dir...]" >&2
    exit 1
fi

THEME_DIR="$HOME/.local/state/caelestia/theme"
MC_DIRS_CONF="$HOME/.local/bin/posthooks/minecraft/mcdirs.conf"

if [[ ! -d "$THEME_DIR" ]]; then
    echo "Theme not installed. Run install.sh first." >&2
    exit 1
fi

for dir in "$@"; do
    clean_path="${dir/#\~/$HOME}"
    clean_path="${clean_path%/}"

    if [[ ! -d "$clean_path" ]]; then
        echo "Directory does not exist: $clean_path" >&2
        continue
    fi

    if grep -Fxq "$clean_path" "$MC_DIRS_CONF" 2>/dev/null; then
        echo "Already tracked: $clean_path"
    else
        echo "$clean_path" >> "$MC_DIRS_CONF"
        echo "Added: $clean_path"
    fi

    target="$clean_path/caelestia"
    mkdir -p "$target"
    rsync -a --delete "$THEME_DIR/" "$target/"
    echo "Copied theme to $target"
done
