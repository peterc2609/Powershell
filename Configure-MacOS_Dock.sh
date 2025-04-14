#!/bin/bash

# Variables
logFile="/var/log/dockutil-dock-config.log"
currentUser=$(stat -f "%Su" /dev/console)
userHome="/Users/$currentUser"
dockutil="/usr/local/bin/dockutil"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$logFile"
}

log "=== Starting Dock configuration ==="
log "Current user: $currentUser"

# Check if dockutil exists
if [ ! -x "$dockutil" ]; then
    log "❌ dockutil not found at $dockutil. Please install dockutil before running this script."
    exit 1
fi

# Apps to remove
appsToRemove=(
    "FaceTime"
    "Calendar"
    "Contacts"
    "Reminders"
    "Notes"
    "Freeform"
    "TV"
    "News"
    "Keynote"
    "Numbers"
    "Pages"
    "App Store"
)

# Remove specified apps from the Dock
for app in "${appsToRemove[@]}"; do
    log "Attempting to remove '$app' from the Dock..."
    "$dockutil" --remove "$app" --no-restart "$userHome" >> "$logFile" 2>&1
done

# Ensure Launchpad is pinned (add if not already present)
if ! "$dockutil" --list "$userHome" | grep -q "Launchpad"; then
    log "Adding Launchpad to the Dock..."
    "$dockutil" --add "/System/Applications/Launchpad.app" --no-restart "$userHome" >> "$logFile" 2>&1
else
    log "Launchpad already present in Dock."
fi

# Restart Dock
log "Restarting Dock..."
killall Dock

log "✅ Dock has been updated successfully."
log "=== Dock configuration complete ==="

exit 0
