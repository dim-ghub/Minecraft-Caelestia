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
    "hyprland"
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

mkdir -p "$POSTHOOKS_DIR/minecraft/RP"
cp -r "$PROJECT_ROOT/posthook"/* "$POSTHOOKS_DIR/"

# ------------------------

# ------------------------

echo ""
echo "============================================================"
echo "                         SETUP"
echo "============================================================"

echo "Reloading wallpaper..."
WALLPAPER_FILE=$(caelestia wallpaper)
caelestia wallpaper -f $WALLPAPER_FILE
read -p "Path to your Minecraft Catppucin resource pack: " rp_path
chmod +x "$PROJECT_ROOT/scripts/set-rp.sh"
"$PROJECT_ROOT/scripts/set-rp.sh" $rp_path || exit 1
"$HOME/.local/bin/posthooks/minecraft.sh" -a
echo "Done! Don't forget to add ~/.local/bin/posthooks/minecraft.sh to your posthook if you want to automate the process."
