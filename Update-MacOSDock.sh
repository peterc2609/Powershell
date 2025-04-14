#!/bin/bash

# -------------------------
# Config
# -------------------------
pkgURL="https://<yourstorage>.blob.core.windows.net/<container>/dockutil.pkg"  # ← Replace this with your Azure Blob URL
tempPkg="/tmp/dockutil.pkg"
dockutil="/usr/local/bin/dockutil"
logFile="/var/log/dockutil-install.log"

# -------------------------
# Log helper
# -------------------------
log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") $1" | tee -a "$logFile"
}

log "=== Starting dockutil installation and Dock configuration script ==="

# -------------------------
# Check and install dockutil
# -------------------------
if [ ! -x "$dockutil" ]; then
    log "dockutil not found — downloading from Azure blob..."

    curl -L "$pkgURL" -o "$tempPkg"
    curlStatus=$?

    if [ $curlStatus -ne 0 ]; then
        log "ERROR: Failed to download dockutil.pkg (curl exit code $curlStatus)"
        exit 1
    fi

    if [ ! -f "$tempPkg" ]; then
        log "ERROR: dockutil.pkg not found at $tempPkg after download."
        exit 1
    fi

    if ! file "$tempPkg" | grep -q "xar archive"; then
        log "ERROR: Downloaded file is not a valid .pkg file."
        exit 1
    fi

    log "Installing dockutil..."
    sudo installer -pkg "$tempPkg" -target /
    installStatus=$?

    if [ $installStatus -ne 0 ]; then
        log "ERROR: Installer failed with exit code $installStatus"
        exit 1
    fi

    log "Cleaning up downloaded package..."
    rm -f "$tempPkg"
    log "dockutil installation completed successfully."
else
    log "dockutil is already installed."
fi

# -------------------------
# Dock customization
# -------------------------
log "Starting Dock customization..."

currentUser=$(stat -f "%Su" /dev/console)
userHome="/Users/$currentUser"

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

# Remove specified apps
for app in "${appsToRemove[@]}"; do
    log "Removing $app from Dock..."
    "$dockutil" --remove "$app" --no-restart "$userHome" >> "$logFile" 2>&1
done

# Add Launchpad if not present
if ! "$dockutil" --list "$userHome" | grep -q "Launchpad"; then
    log "Adding Launchpad to Dock..."
    "$dockutil" --add "/System/Applications/Launchpad.app" --no-restart "$userHome" >> "$logFile" 2>&1
else
    log "Launchpad already present in Dock."
fi

# Apply changes
killall Dock
log "Dock has been updated successfully."
log "=== Script complete ==="

exit 0
