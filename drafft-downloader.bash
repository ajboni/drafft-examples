#!/bin/bash
# Built by Wade Schneider @ Nano Game Lab -> https://github.com/The-Maize . For the use strctly with Drafft2 game development software, developed by baj -> https://drafft.dev

set -eo pipefail

# ====== Config ======
GITHUB_API_URL="https://api.github.com/repos/ajboni/drafft-releases/releases/latest"
APP_ENV_VAR="DRAFFT2_INSTALL_LOCATION"
# APP_DOWNLOAD_URL="https://example.com/drafft2-latest"  # <-- set your real URL here best to shorten then use drafft2-latest so it can simply be grabbed regardless of current version. (feel free to add version checks.)
APP_DOWNLOAD_URL=$(curl -s "$GITHUB_API_URL" | grep "browser_download_url" | grep "linux-x86_64.AppImage" | cut -d '"' -f 4)
APP_IMAGE_NAME="drafft2-latest"
EXTRACTED_TEMP_FOLDER="squashfs-root"
TARGET_FOLDER_NAME="drafft2-latest"
APPLICATIONS_DIR="$HOME/.Applications" # not strictly necissary added here for debugging during creation.
DESKTOP_ENTRY="$HOME/.local/share/applications/drafft_2.desktop"

# ====== Globals ======
MANUAL_ONLY=false
VERBOSE=false
DRY_RUN=false


# ====== Functions ======
log() {
    echo -e "\e[1;32m[INFO]\e[0m $1"
}

debug() {
    if [ "$VERBOSE" = true ]; then
        echo -e "\e[1;34m[DEBUG]\e[0m $1"
    fi
}

error_exit() {
    echo -e "\e[1;31m[ERROR]\e[0m $1" >&2
    exit 1
}

check_dependency() {
    command -v "$1" &> /dev/null || error_exit "Missing required command: $1"
}

prompt_install_mode() {
    echo -e "\nDo you want to (U)pdate existing installation or perform a (F)resh install? U = Update | F = Fresh Install"
    read -rp "[U/F]: " choice
    case "${choice^^}" in
        U) echo "update" ;;
        F) echo "fresh" ;;
        *) log "Invalid input, assuming update."; echo "update" ;;
    esac
}

append_to_shell_rc() {
    local new_value="$1"
    local export_line="export $APP_ENV_VAR=\"$new_value\""

    local current_shell
    current_shell="$(ps -p $$ -o comm=)"

    local shell_rc
    if [[ "$current_shell" == *zsh* ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ "$current_shell" == *bash* ]]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.bashrc"
    fi

    if grep -q "^export $APP_ENV_VAR=" "$shell_rc"; then
        local existing_value
        existing_value=$(grep "^export $APP_ENV_VAR=" "$shell_rc" | sed -E "s/^export $APP_ENV_VAR=\"(.*)\"/\1/")
        if [ "$existing_value" != "$new_value" ]; then
            sed -i "s|^export $APP_ENV_VAR=.*|$export_line|" "$shell_rc"
            log "Updated $APP_ENV_VAR in $shell_rc to: $new_value"
        else
            debug "$APP_ENV_VAR already set correctly in $shell_rc."
        fi
    else
        echo "$export_line" >> "$shell_rc"
        log "Added $APP_ENV_VAR to $shell_rc."
    fi
}




# Simple help if needed with a few arguments for the end user
print_help() {
    echo "Usage: $0 [--manual-only] [--verbose] [--help]"
    echo ""
    echo "Options:"
    echo "  --manual-only   Disable downloading. Only use AppImage placed next to this script."
    echo "  --dry-run       Do not download or install anything, just print what would be done."
    echo "  --verbose       Show debug output."
    echo "  --help          Show this help message."
    exit 0
}




# ====== Parse Arguments ======
for arg in "$@"; do
    case "$arg" in
        --manual-only) MANUAL_ONLY=true ;;
        --verbose) VERBOSE=true ;;
        --help) print_help ;;
        *) error_exit "Unknown option: $arg" ;;
    esac
done

set -u




# ====== Check prerequisites ======
check_dependency sed
check_dependency sudo
check_dependency realpath
check_dependency curl



# ====== Step 1: Detect or set install location ======
install_mode="update"
value=""

if [ -z "${!APP_ENV_VAR:-}" ]; then
    for rcfile in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rcfile" ]; then
            value=$(grep -E "^export $APP_ENV_VAR=" "$rcfile" | sed -E "s/^export $APP_ENV_VAR=\"(.*)\"/\1/" || true)
            if [ -n "$value" ]; then
                export $APP_ENV_VAR="$value"
                log "Found $APP_ENV_VAR in $rcfile: $value"
                break
            fi
        fi
    done
fi

if [ -z "${!APP_ENV_VAR:-}" ] || [ ! -d "${!APP_ENV_VAR:-}" ]; then
    log "No existing install location detected."
    install_mode="fresh"
else
    install_mode=$(prompt_install_mode)
fi

if [ "$install_mode" == "fresh" ]; then
    read -rp "Enter install location for fresh install (full path, folder will be created if not exists): " user_input
    mkdir -p "$user_input"
    export $APP_ENV_VAR="$user_input"
    log "Set $APP_ENV_VAR to $user_input"
fi

INSTALL_DIR="${!APP_ENV_VAR:-}"
INSTALL_DIR="${INSTALL_DIR%/}"
INSTALL_DIR="$(realpath "$INSTALL_DIR")"
log "Using install location: $INSTALL_DIR"

append_to_shell_rc "$INSTALL_DIR"

TARGET_FULL_PATH="$INSTALL_DIR/$TARGET_FOLDER_NAME"




# ====== Step 2: Find AppImage in script folder or download ======
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manual_appimage=$(find "$SCRIPT_DIR" -maxdepth 1 -type f -iname "Drafft-2*.AppImage" | head -n 1 || true)

TEMP_APPIMAGE="/tmp/$APP_IMAGE_NAME"
if [ -n "$manual_appimage" ]; then
    log "Found AppImage next to installer: $manual_appimage"
    cp "$manual_appimage" "$TEMP_APPIMAGE"
elif [ "$MANUAL_ONLY" = false ]; then
    check_dependency wget
    log "No local AppImage found. Downloading latest AppImage..."
    wget -O "$TEMP_APPIMAGE" "$APP_DOWNLOAD_URL"
else
    error_exit "No AppImage found and manual-only mode is enabled."
fi

chmod +x "$TEMP_APPIMAGE"




# ====== Step 3: Handle existing folder for update ======
if [ "$install_mode" == "update" ] && [ -d "$TARGET_FULL_PATH" ]; then
    log "Removing old installation at $TARGET_FULL_PATH..."
    rm -rf "$TARGET_FULL_PATH"
fi

mkdir -p "$INSTALL_DIR"
cd "$(dirname "$TEMP_APPIMAGE")"

log "Extracting AppImage..."
./"$(basename "$TEMP_APPIMAGE")" --appimage-extract

log "Moving extracted folder to $TARGET_FULL_PATH"
mv "$EXTRACTED_TEMP_FOLDER" "$TARGET_FULL_PATH"

rm -f "$TEMP_APPIMAGE"




# ====== Step 4: Set chrome-sandbox permissions ======
cd "$TARGET_FULL_PATH" || error_exit "Cannot enter $TARGET_FULL_PATH"
if [ -f "chrome-sandbox" ]; then
    sudo chown root:root chrome-sandbox
    sudo chmod 4755 chrome-sandbox
    log "chrome-sandbox permissions set."
else
    log "No chrome-sandbox found, skipping permissions."
fi




# ====== Step 5: Handle desktop entry ======
if [ ! -f "$DESKTOP_ENTRY" ]; then
    if [ -f drafft_2.desktop ]; then
        cp drafft_2.desktop "$DESKTOP_ENTRY"
        log "Desktop entry created."
    else
        log "drafft_2.desktop template not found, skipping desktop entry creation."
    fi
fi

if [ -f "$DESKTOP_ENTRY" ]; then
    exec_path="$TARGET_FULL_PATH/drafft_2"
    icon_path="$TARGET_FULL_PATH/usr/share/icons/hicolor/1024x1024/apps/drafft_2.png"

    # replace any existing Exec= line
    sed -i "s|^Exec=.*|Exec=$exec_path|g" "$DESKTOP_ENTRY"
    # replace any existing Icon= line
    sed -i "s|^Icon=.*|Icon=$icon_path|g" "$DESKTOP_ENTRY"

    log "Desktop entry paths corrected."
fi

log "Installation process ($install_mode) completed successfully."
