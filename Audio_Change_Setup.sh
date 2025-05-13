#!/bin/bash
set -e # Exit immediately if a command fails.

# --- Config (Hardcoded) ---
SOURCE_SCRIPT="./Change_Audio_Output_Port.sh"
TARGET_SCRIPT="/bin/Change_Audio_Output_Port.sh"
SLOT_INDEX="99" # Using a fixed slot index - will overwrite if used!
SLOT_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom${SLOT_INDEX}/"
SHORTCUT_NAME="Change Audio Output"
SHORTCUT_BINDING="F12"
MEDIA_KEYS_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"

# --- SUDO_USER Check ---
if [ -z "$SUDO_USER" ]; then
  echo "ERROR: This script must be run with sudo, and SUDO_USER must be set." >&2
  echo "       Example: sudo ./your_script_name.sh" >&2
  exit 1
fi
REAL_USER_ID=$(id -u "$SUDO_USER")

# --- File Operations (Run as root via sudo) ---

# 1. Move file
echo "Moving '$SOURCE_SCRIPT' to '$TARGET_SCRIPT'..."
mv -f "$SOURCE_SCRIPT" "$TARGET_SCRIPT"

# 2. Make executable
echo "Making '$TARGET_SCRIPT' executable..."
chmod +x "$TARGET_SCRIPT"

# --- Shortcut Setup (Attempt to run as the original user) ---
echo "Attempting to set GNOME shortcut for user $SUDO_USER..."

# Try to determine the original user's D-Bus session address
DBUS_SESSION_BUS_ADDRESS_DETECTED=""

# Method 1: Check the standard path /run/user/<UID>/bus
USER_BUS_PATH="/run/user/$REAL_USER_ID/bus"
if [ -S "$USER_BUS_PATH" ]; then # -S checks if it's a socket
    DBUS_SESSION_BUS_ADDRESS_DETECTED="unix:path=$USER_BUS_PATH"
    echo "Found D-Bus address via $USER_BUS_PATH"
fi

# Method 2: Fallback by checking environment of user's session process (less reliable but common)
if [ -z "$DBUS_SESSION_BUS_ADDRESS_DETECTED" ]; then
    SESSION_PROCESS_PID=$(pgrep -u "$SUDO_USER" -x "(gnome-session|gnome-session-binary|plasma_session|xfce4-session)" | head -n 1)
    if [ -n "$SESSION_PROCESS_PID" ]; then
        DBUS_SESSION_BUS_ADDRESS_DETECTED=$(grep -z DBUS_SESSION_BUS_ADDRESS "/proc/$SESSION_PROCESS_PID/environ" | cut -d= -f2-)
        if [ -n "$DBUS_SESSION_BUS_ADDRESS_DETECTED" ]; then
             echo "Found D-Bus address via session process $SESSION_PROCESS_PID"
        fi
    fi
fi

if [ -z "$DBUS_SESSION_BUS_ADDRESS_DETECTED" ]; then
    echo "WARNING: Could not reliably determine the D-Bus session address for user $SUDO_USER." >&2
    echo "         The gsettings commands will be attempted without it, which may fail." >&2
    echo "         If shortcuts are not set, please add them manually via GNOME Settings." >&2
    # Define GSET_CMD to run as original user, but without explicit D-Bus (might still work in some sudo setups)
    GSET_CMD="sudo -u $SUDO_USER"
else
    # Define GSET_CMD to run as original user WITH the detected D-Bus address
    # The "DISPLAY=:0" is often helpful for GUI related commands under sudo, though D-Bus is primary for gsettings.
    GSET_CMD="sudo -u $SUDO_USER DBUS_SESSION_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS_DETECTED DISPLAY=:0"
fi

# 3. Set shortcut properties using the constructed GSET_CMD
echo "Setting GNOME shortcut properties for slot custom${SLOT_INDEX}..."
$GSET_CMD gsettings set "${MEDIA_KEYS_SCHEMA}.custom-keybinding:${SLOT_PATH}" name "$SHORTCUT_NAME"
$GSET_CMD gsettings set "${MEDIA_KEYS_SCHEMA}.custom-keybinding:${SLOT_PATH}" command "$TARGET_SCRIPT"
$GSET_CMD gsettings set "${MEDIA_KEYS_SCHEMA}.custom-keybinding:${SLOT_PATH}" binding "$SHORTCUT_BINDING"

# 4. Add slot to the main list using the constructed GSET_CMD
echo "Adding slot custom${SLOT_INDEX} to the active list..."
CURRENT_LIST=$($GSET_CMD gsettings get "$MEDIA_KEYS_SCHEMA" custom-keybindings 2>/dev/null || echo "[]")

# Basic append string manipulation - will add if not present, no complex list parsing
if ! echo "$CURRENT_LIST" | grep -qF "'$SLOT_PATH'"; then # -F for fixed string, -q for quiet
    if [[ "$CURRENT_LIST" == "[]" || "$CURRENT_LIST" == "@as []" ]]; then
        NEW_LIST="['$SLOT_PATH']"
    else
        NEW_LIST="${CURRENT_LIST%]*}, '$SLOT_PATH']" # Remove trailing ']', add comma, new path (quoted), add ']' back
    fi
    $GSET_CMD gsettings set "$MEDIA_KEYS_SCHEMA" custom-keybindings "$NEW_LIST"
else
    echo "Slot path '$SLOT_PATH' already in list. No change to list needed."
fi

echo "--- Script finished ---"
echo "If shortcuts failed, ensure you ran with 'sudo' (not 'sudo -E' for this version)."
echo "and check GNOME Settings manually."
exit 0
