#!/bin/bash

# Darkhosting Paymenter Installer
# Made by Nikhil

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Download the main script
curl -o darkhosting-paymenter-installer.sh https://github.com/princekop/Paymenter-Script/blob/main/darkhosting-paymenter-installer.sh

# Make it executable
chmod +x darkhosting-paymenter-installer.sh

# Run the script
./darkhosting-paymenter-installer.sh

# Clean up
rm darkhosting-paymenter-installer.sh
