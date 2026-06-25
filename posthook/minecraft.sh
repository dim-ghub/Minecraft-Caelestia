#!/bin/bash

INPUT_DIR="$HOME/.local/bin/posthooks/minecraft/RP"
MC_DIRS_CONF="$HOME/.local/bin/posthooks/minecraft/mcdirs.conf"
PY_SCRIPT="$HOME/.local/bin/posthooks/minecraft/recolor.py"
THEME_DIR="$HOME/.local/state/caelestia/theme"

USED_COLORS=(
    "#9399b2" "#7f849c" "#6c7086" "#585b70"
    "#45475a" "#313244" "#1e1e2e" "#181825"
    "#11111b"
)

VERBOSE=0

for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

log() {
    [[ $VERBOSE -eq 1 ]] && echo "$@"
}

SCHEME_OUTPUT=$(caelestia scheme get 2>/dev/null)
if [[ -z "$SCHEME_OUTPUT" ]]; then
    echo "Failed to get scheme from caelestia!"
    exit 1
fi

get_color() {
    local color_name="$1"
    echo "$SCHEME_OUTPUT" | sed 's/\x1b\[[0-9;]*m//g' | grep -E "^[[:space:]]+$color_name:" | awk '{print "#" $2}'
}

REPLACEMENT_COLORS=(
    "$(get_color primaryFixedDim)"
    "$(get_color secondaryFixedDim)"
    "$(get_color secondaryFixed)"
    "$(get_color tertiaryFixedDim)"
    "$(get_color tertiaryFixed)"
    "$(get_color surfaceVariant)"
    "$(get_color surface)"
    "$(get_color primaryContainer)"
    "$(get_color surface)"
)

for color in "${REPLACEMENT_COLORS[@]}"; do
    if [[ -z "$color" || "$color" == "#" ]]; then
        echo "Missing replacement colors!"
        exit 1
    fi
done

mkdir -p "$THEME_DIR"

log "Syncing non-image files..."
cp "$INPUT_DIR/pack.png" "$INPUT_DIR/pack.mcmeta" "$THEME_DIR/" 2>/dev/null || true
rsync -a --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' "$INPUT_DIR/" "$THEME_DIR/"

log "Queueing image jobs..."
BASE_PALETTE_JSON=$(printf '%s\n' "${USED_COLORS[@]}" | jq -R . | jq -s .)
TARGET_PALETTE_JSON=$(printf '%s\n' "${REPLACEMENT_COLORS[@]}" | jq -R . | jq -s .)

jobfile=$(mktemp)
recolor_count=0

while IFS= read -r -d '' file; do
    rel_path="${file#$INPUT_DIR/}"
    out_path="$THEME_DIR/$rel_path"

    jq -cn \
        --arg img "$file" \
        --arg out "$out_path" \
        --argjson base "$BASE_PALETTE_JSON" \
        --argjson target "$TARGET_PALETTE_JSON" \
        '{img_path: $img, out_path: $out, base_palette: $base, target_palette: $target}' >> "$jobfile"
    ((recolor_count++))
done < <(find "$INPUT_DIR" -type f -iregex '.*\.\(png\|jpe?g\)' -not -name 'pack.png' -print0)

# Convert newline-delimited JSON objects to a JSON array
jq -s '.' "$jobfile" > "${jobfile}.tmp" && mv "${jobfile}.tmp" "$jobfile"

if [[ $recolor_count -eq 0 ]]; then
    echo "No images found to recolor."
    rm -f "$jobfile"
    exit 0
fi

log "Recoloring $recolor_count image(s)..."
python3 "$PY_SCRIPT" < "$jobfile"

echo "Done. $recolor_count image(s) recolored."
rm -f "$jobfile"

# Sync theme to tracked resource pack directories
if [[ -f "$MC_DIRS_CONF" ]]; then
    log "Syncing to resource pack directories..."
    while IFS= read -r dir; do
        [[ -z "$dir" || "$dir" =~ ^[[:space:]]*$ ]] && continue
        clean="${dir/#\~/$HOME}"
        clean="${clean%/}"
        if [[ -d "$clean" ]]; then
            target="$clean/caelestia"
            mkdir -p "$target"
            rsync -a --delete "$THEME_DIR/" "$target/"
            log "Synced to $target"
        fi
    done < "$MC_DIRS_CONF"
fi

# Update acrylic.ini background color for each tracked instance
SURFACE_HEX=$(get_color surface | sed 's/^#//')
if [[ -n "$SURFACE_HEX" ]]; then
    SURFACE_DEC=$(printf "%d" "0x$SURFACE_HEX")
    log "Surface color: #$SURFACE_HEX -> decimal $SURFACE_DEC"

    if [[ -f "$MC_DIRS_CONF" ]]; then
        while IFS= read -r dir; do
            [[ -z "$dir" || "$dir" =~ ^[[:space:]]*$ ]] && continue
            clean="${dir/#\~/$HOME}"
            clean="${clean%/}"
            INI_FILE="$(dirname "$clean")/config/acrylic.ini"
            if [[ -f "$INI_FILE" ]]; then
                sed -i "s/^background_color_rgb=.*/background_color_rgb=$SURFACE_DEC/" "$INI_FILE"
                log "Updated $INI_FILE"
            fi
        done < "$MC_DIRS_CONF"
    fi
fi

# Auto-reload Minecraft textures if it's the focused window
FOCUSED_ADDR=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address' 2>/dev/null || echo "")
IS_MINECRAFT=$(hyprctl clients -j 2>/dev/null | jq -r --arg addr "$FOCUSED_ADDR" '.[] | select(.address == $addr) | select(.title | test("^Minecraft"; "i")) | .address' 2>/dev/null)

if [[ -n "$IS_MINECRAFT" ]]; then
    if pgrep -x ydotoold > /dev/null; then
        YDOTOLD_WAS_RUNNING=1
    else
        YDOTOLD_WAS_RUNNING=0
        ydotoold &
        sleep 1
    fi

    ydotool key 61:1 20:1 20:0 61:0

    sleep 0.5

    if [[ $YDOTOLD_WAS_RUNNING -eq 0 ]]; then
        pkill ydotoold
    fi
fi
