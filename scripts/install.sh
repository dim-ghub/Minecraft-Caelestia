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

# Dynamically find the project root regardless of where this script is called from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

POSTHOOKS_DIR="$HOME/.local/bin/posthooks"
THEME_DIR="$HOME/.local/state/caelestia/theme"
CONFIG_DIR="$HOME/.config/caelestia"
CLI_JSON="$CONFIG_DIR/cli.json"

# --- Check for existing installation ---
chmod +x "$PROJECT_ROOT/scripts/uninstall.sh"
if [[ -d "$POSTHOOKS_DIR/minecraft" ]]; then
    echo ""
    echo "============================================================"
    echo "                    CLEAN UP / UPDATE"
    echo "============================================================"
    echo "Previous installation exists, cleaning and updating..."
    "$PROJECT_ROOT/scripts/uninstall.sh"
fi
# ------------------------

# --- installation ---
echo ""
echo "============================================================"
echo "                       INSTALLING"
echo "============================================================"

# Check package dependencies

DEPENDENCIES=(
    "rsync"
    "python3"
    "ydotool"
    "jq"
    "hyprctl"
    "curl"
    "unzip"
)

PYTHON_DEPS=(
    "numpy"
    "PIL"
)

echo "Checking dependencies..."
missing_dep=0

for pkg in "${DEPENDENCIES[@]}"; do
    if ! command -v "$pkg" > /dev/null; then
        missing_dep=1
        echo "Missing dependency: $pkg" >&2
    fi
done

for pkg in "${PYTHON_DEPS[@]}"; do
    if ! python3 -c "import $pkg" > /dev/null; then
        missing_dep=1
        echo "Missing python dependency: $pkg" >&2
    fi
done

if [ $missing_dep -ne 0 ]; then
    echo "Please install dependencies and try again!"
    exit 1
else
    echo "✓ All dependencies met."
fi

# Create directories
mkdir -p "$POSTHOOKS_DIR/minecraft/RP"
mkdir -p "$THEME_DIR"

# Copy posthook scripts
cp -r "$PROJECT_ROOT/posthook"/* "$POSTHOOKS_DIR/"

# Download Catppuccin Mocha Blue from Modrinth
echo ""
echo "============================================================"
echo "                       SETUP"
echo "============================================================"

FILENAME="Catppuccin Mocha Blue.zip"
echo ""
echo "Downloading ${FILENAME} from Modrinth..."

API_RESPONSE=$(curl -s "https://api.modrinth.com/v2/project/catppuccin-ui/version?loaders=%5B%22minecraft%22%5D" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$API_RESPONSE" ]; then
    echo "Failed to fetch version info from Modrinth!" >&2
    exit 1
fi

VERSION_ID=$(echo "$API_RESPONSE" | jq -r '.[] | select(.name | startswith("Catppuccin Mocha")) | .id' 2>/dev/null | head -1)
if [ -z "$VERSION_ID" ]; then
    echo "Could not find Mocha version!" >&2
    exit 1
fi

DOWNLOAD_URL=$(echo "$API_RESPONSE" | jq -r --arg vid "$VERSION_ID" --arg fname "$FILENAME" '.[] | select(.id == $vid) | .files[] | select(.filename == $fname) | .url' 2>/dev/null)
if [ -z "$DOWNLOAD_URL" ]; then
    echo "Could not find download URL for ${FILENAME}!" >&2
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl -L -o "$TMPDIR/pack.zip" "$DOWNLOAD_URL" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Failed to download resource pack!" >&2
    exit 1
fi

rm -rf "$POSTHOOKS_DIR/minecraft/RP/"*
unzip -q "$TMPDIR/pack.zip" -d "$POSTHOOKS_DIR/minecraft/RP"
if [ $? -ne 0 ]; then
    echo "Failed to extract resource pack!" >&2
    exit 1
fi

echo "✓ Downloaded and extracted ${FILENAME}"

# Reload wallpaper to generate scheme
echo ""
echo "Reloading wallpaper..."
WALLPAPER_FILE=$(caelestia wallpaper)
caelestia wallpaper -f "$WALLPAPER_FILE"

# Update cli.json posthook
echo ""
echo "============================================================"
echo "                    CONFIGURING CLI"
echo "============================================================"

POSTHOOK_CMD="$POSTHOOKS_DIR/minecraft.sh"

mkdir -p "$CONFIG_DIR"

if [[ -f "$CLI_JSON" ]]; then
    EXISTING_HOOK=$(jq -r '.wallpaper.postHook // empty' "$CLI_JSON" 2>/dev/null)

    if [[ -n "$EXISTING_HOOK" ]]; then
        if [[ "$EXISTING_HOOK" == *"$POSTHOOK_CMD"* ]]; then
            echo "✓ Posthook already configured in cli.json"
        else
            NEW_HOOK="${EXISTING_HOOK} && ${POSTHOOK_CMD}"
            jq --arg hook "$NEW_HOOK" '.wallpaper.postHook = $hook' "$CLI_JSON" > "$CLI_JSON.tmp" && mv "$CLI_JSON.tmp" "$CLI_JSON"
            echo "✓ Added minecraft posthook to wallpaper.postHook in cli.json"
        fi
    else
        jq --arg hook "$POSTHOOK_CMD" '.wallpaper.postHook = $hook' "$CLI_JSON" > "$CLI_JSON.tmp" && mv "$CLI_JSON.tmp" "$CLI_JSON"
        echo "✓ Created wallpaper.postHook in cli.json"
    fi
else
    echo "ERROR: cli.json not found at $CLI_JSON" >&2
    exit 1
fi

echo ""
echo "============================================================"
echo "                         DONE"
echo "============================================================"
echo ""
echo "To add resource pack directories, run:"
echo "  scripts/add-output-dir.sh <dir> [dir...]"
echo ""
echo "To manually trigger a recolor:"
echo "  $POSTHOOKS_DIR/minecraft.sh"
