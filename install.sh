#!/bin/bash

# 1. Safety Check: Ensure run as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Please run as root (sudo ./install.sh)"
  exit 1
fi

# 2. Get Absolute Path of the Repo
# System symlinks MUST point to absolute paths to work reliably.
REPO_DIR=$(pwd)

# Verify we are in the right place
if [ ! -f "$REPO_DIR/usr/local/bin/smart-battery-priority.sh" ]; then
  echo "❌ Error: Source files not found."
  echo "   Please run this script from the root of the git repository."
  exit 1
fi

echo "🔗 Linking T480 Battery Manager from: $REPO_DIR"

# --- INSTALLATION (SYMLINKS) ---

# 3. Link the Logic Script
# Target: /usr/local/bin/smart-battery-priority.sh
echo "➡️  Linking logic script..."
ln -sf "$REPO_DIR/usr/local/bin/smart-battery-priority.sh" /usr/local/bin/smart-battery-priority.sh
# Ensure the source file is executable
chmod +x "$REPO_DIR/usr/local/bin/smart-battery-priority.sh"

# 4. Link Udev Rule
# Target: /etc/udev/rules.d/99-smart-battery.rules
echo "➡️  Linking udev rule..."
ln -sf "$REPO_DIR/etc/udev/rules.d/99-smart-battery.rules" /etc/udev/rules.d/99-smart-battery.rules

# 5. Link TLP Configuration
# Target: /etc/tlp.conf
echo "➡️  Linking TLP config..."
if [ -f /etc/tlp.conf ] && [ ! -L /etc/tlp.conf ]; then
    # Back up only if it's a real file (not already a link)
    BACKUP_NAME="/etc/tlp.conf.bak-$(date +%F-%H%M)"
    mv /etc/tlp.conf "$BACKUP_NAME"
    echo "    ℹ️  Moved original config to $BACKUP_NAME"
fi
ln -sf "$REPO_DIR/etc/tlp.conf" /etc/tlp.conf

# --- ACTIVATION ---

echo "🔄 Reloading system services..."

# Reload udev database
udevadm control --reload-rules

# Trigger events to sync state
udevadm trigger --subsystem-match=power_supply

# Restart TLP to read the linked config
tlp start

echo "✅ Smart Mode Active!"
echo "   Edits in '$REPO_DIR' will now reflect instantly as files re symlinked ."
echo "   journalctl -t smartbat -f"
