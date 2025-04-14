#!/bin/bash

# Get the current logged-in user
currentUser=$(stat -f "%Su" /dev/console)
userHome="/Users/$currentUser"

# Path to dockutil
dockutil="/usr/local/bin/dockutil"

# Check if dockutil exists
if [ ! -x "$dockutil" ]; then
    echo "❌ dockutil not found at $dockutil. Please install dockutil before running this script."
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
    "$dockutil" --remove "$app" --no-restart "$userHome"
done

# Ensure Launchpad is pinned (add if not already present)
if ! "$dockutil" --list "$userHome" | grep -q "Launchpad"; then
    "$dockutil" --add "/System/Applications/Launchpad.app" --no-restart "$userHome"
fi

# Restart Dock to apply changes
killall Dock

echo "✅ Dock has been updated."
exit 0
