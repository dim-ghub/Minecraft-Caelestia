#!/bin/bash

INPUT_DIR="$HOME/.local/bin/posthooks/minecraft/RP"
MC_DIRS_CONF="$HOME/.local/bin/posthooks/minecraft/mcdirs.conf"
PY_SCRIPT="$HOME/.local/bin/posthooks/minecraft/recolor.py"

USED_COLORS=(
    "#9399b2" "#7f849c" "#6c7086" "#585b70"
    "#45475a" "#313244" "#1e1e2e" "#181825"
    "#11111b"
)

VERBOSE=0
ADD_DIRS=0

for arg in "$@"; do
    case "$arg" in
        -v|--verbose) VERBOSE=1 ;;
        -a|--add) ADD_DIRS=1 ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

log() {
    [[ $VERBOSE -eq 1 ]] && echo "$@"
}

if [[ $ADD_DIRS -eq 1 ]]; then
    echo "Add output directories (type 'done' when finished):"
    while true; do
        read -rp "Directory path: " newdir
        [[ "$newdir" == "done" ]] && break
        [[ -z "$newdir" ]] && continue
        clean_path="${newdir/#\~/$HOME}"
        clean_path="${clean_path%/}"
        if grep -Fxq "$clean_path" "$MC_DIRS_CONF"; then
            echo "Already in config: $clean_path"
        else
            echo "$clean_path" >> "$MC_DIRS_CONF"
            echo "Added: $clean_path"
        fi
    done
    read -rp "Run the recolor script now? [Y/n] " confirm
    confirm="${confirm:-Y}"
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
fi

SCHEME_OUTPUT=$(caelestia scheme get 2>/dev/null)
if [[ -z "$SCHEME_OUTPUT" ]]; then
    echo "Failed to get scheme from caelestia!"
    exit 1
fi

get_color() {
    local color_name="$1"
    echo "$SCHEME_OUTPUT" | grep -E "^[[:space:]]+$color_name:" | awk '{print "#" $2}'
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

mapfile -t OUTPUT_DIRS < <(
    grep -v '^[[:space:]]*$' "$MC_DIRS_CONF" | sed 's|~|'"$HOME"'|' | sed 's|/*$||' | awk '{ print $0 "/caelestia" }'
)
[[ ${#OUTPUT_DIRS[@]} -eq 0 ]] && echo "No output directories configured!" && exit 1

SOURCE_DIR="$HOME/.local/bin/posthooks/minecraft"

log "Syncing non-image files..."
for out in "${OUTPUT_DIRS[@]}"; do
    mkdir -p "$out"
    cp "$SOURCE_DIR/pack.png" "$SOURCE_DIR/pack.mcmeta" "$out/" 2>/dev/null || true
    rsync -a --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' "$INPUT_DIR/" "$out/"
done

log "Queueing image jobs..."
BASE_PALETTE_JSON="[$(printf '"%s",' "${USED_COLORS[@]}" | sed 's/,$//')]"
TARGET_PALETTE_JSON="[$(printf '"%s",' "${REPLACEMENT_COLORS[@]}" | sed 's/,$//')]"

jobfile=$(mktemp)
echo "[" > "$jobfile"
sep=""

recolor_count=0

while IFS= read -r -d '' file; do
    rel_path="${file#$INPUT_DIR/}"

    for out in "${OUTPUT_DIRS[@]}"; do
        out_path="$out/$rel_path"

        echo "${sep}{\"img_path\": \"$file\", \"out_path\": \"$out_path\", \"base_palette\": $BASE_PALETTE_JSON, \"target_palette\": $TARGET_PALETTE_JSON}" >> "$jobfile"
        sep=","
        ((recolor_count++))
    done
done < <(find "$INPUT_DIR" -type f -iregex '.*\.\(png\|jpe?g\)' -not -name 'pack.png' -print0)

echo "]" >> "$jobfile"

if [[ $recolor_count -eq 0 ]]; then
    echo "No images found to recolor."
    rm -f "$jobfile"
    exit 0
fi

log "Recoloring $recolor_count image(s)..."
python3 "$PY_SCRIPT" < "$jobfile"

echo "Done. $recolor_count image(s) recolored."
rm -f "$jobfile"

PREV_FOCUSED=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address' 2>/dev/null || echo "")

MINECRAFT_ADDR=$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.class | test("Minecraft"; "i")) | .address' 2>/dev/null | head -1)
DID_FOCUS=0

if [[ -n "$MINECRAFT_ADDR" ]]; then
    if pgrep -x ydotoold > /dev/null; then
        YDOTOLD_WAS_RUNNING=1
    else
        YDOTOLD_WAS_RUNNING=0
        ydotoold &
        sleep 0.5
    fi

    hyprctl dispatch focuswindow "address:$MINECRAFT_ADDR"
    DID_FOCUS=1
    sleep 0.2

    ydotool key 61:1 20:1 20:0 61:0

    sleep 0.3

    if [[ $YDOTOLD_WAS_RUNNING -eq 0 ]]; then
        pkill ydotoold
    fi
fi

if [[ $DID_FOCUS -eq 1 && -n "$PREV_FOCUSED" ]]; then
    hyprctl dispatch focuswindow "address:$PREV_FOCUSED"
fi
