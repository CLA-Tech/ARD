#!/bin/bash

# Enable Apple Remote Desktop and configure system settings

# Usage: ./enable_ard_full.sh username password

# Check if a username and password are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 username password"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

# Function to check macOS version
check_macos_version() {
    swVersMajor=$(sw_vers -productVersion | awk -F '.' '{print $1}')
    echo "macOS major version detected: $swVersMajor"
}

# Path to the kickstart utility
KICKSTART="/System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart"

# Check if user exists, if not, create the user
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' exists."
else
    echo "User '$USERNAME' does not exist. Creating user..."

    # Generate a unique User ID (UID)
    LASTID=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -n | tail -1)
    UNIQUEID=$((LASTID + 1))

    # Create the user
    sudo dscl . -create /Users/"$USERNAME"
    sudo dscl . -create /Users/"$USERNAME" UserShell /bin/bash
    sudo dscl . -create /Users/"$USERNAME" RealName "$USERNAME"
    sudo dscl . -create /Users/"$USERNAME" UniqueID "$UNIQUEID"
    sudo dscl . -create /Users/"$USERNAME" PrimaryGroupID 20
    sudo dscl . -create /Users/"$USERNAME" NFSHomeDirectory /Users/"$USERNAME"
    echo "$PASSWORD" | sudo dscl . -passwd /Users/"$USERNAME" -
    sudo createhomedir -c -u "$USERNAME" &> /dev/null

    # Uncomment the following line to make the new user an admin
    # sudo dscl . -append /Groups/admin GroupMembership "$USERNAME"
fi

# Enable Remote Apple Events
echo -e "\nEnabling Remote Apple Events..."
sudo systemsetup -setremoteappleevents on

# Enable Remote Login (SSH) for the specified user
echo -e "\nEnabling Remote Login (SSH) for user '$USERNAME'..."
sudo dseditgroup -o create -q com.apple.access_ssh
sudo dseditgroup -o edit -a "$USERNAME" -t user com.apple.access_ssh
sudo systemsetup -setremotelogin on

# Activate Remote Management and allow access for specified users
echo -e "\nActivating Remote Management for user '$USERNAME'..."
sudo "$KICKSTART" -activate -configure -allowAccessFor -specifiedUsers

# Configure access and privileges for the specified user
echo -e "\nConfiguring ARD privileges for user '$USERNAME'..."
sudo "$KICKSTART" -configure -users "$USERNAME" -access -on -privs -all \
    -clientopts -setmenuextra -menuextra yes

# Set the computer to restart automatically after a power failure
echo -e "\nSetting computer to restart automatically after a power failure..."
sudo systemsetup -setrestartpowerfailure on

# Set the computer to wake from sleep when a network admin packet is sent
echo -e "\nEnabling Wake on Network Access..."
sudo systemsetup -setwakeonnetworkaccess on

# Restart the ARD Agent and helper
echo -e "\nRestarting ARD Agent and helper..."
sudo "$KICKSTART" -restart -agent -menu

# Check macOS version and adjust settings if necessary
check_macos_version

if [[ $swVersMajor -ge 12 ]]; then
    echo -e "\nmacOS version is Monterey or newer. Applying additional settings..."
    # Add any macOS Monterey or newer specific settings here
    # For example, adjust privacy permissions or MDM configurations
fi

# If using JAMF, trigger policies as needed
if command -v jamf &> /dev/null; then
    echo -e "\nJAMF detected. Triggering JAMF policies..."
    sudo jamf policy -trigger recon
    # Uncomment the following line if you have a policy named 'ardkickstart'
    # sudo jamf policy -trigger ardkickstart
fi

echo -e "\nApple Remote Desktop and additional settings have been enabled for user '$USERNAME'."
