#!/bin/bash
# filepath: c:\Projects\2025-06\CloudAppInstaller01\src\terraform\scripts\mount-azure-files.sh

set -e

# Variables passed from Terraform
STORAGE_ACCOUNT_NAME="${storage_account_name}"
SHARE_NAME="${share_name}"
MOUNT_POINT="${mount_point}"
MOUNT_OPTIONS="${mount_options}"
MAKE_PERSISTENT="${make_persistent}"

echo "Starting Azure Files mount process..."

# Install required packages
sudo apt-get update -y
sudo apt-get install -y cifs-utils jq

# Create mount point
sudo mkdir -p "$MOUNT_POINT"

# Login using managed identity
echo "Authenticating with managed identity..."
az login --identity

# Get storage account key using managed identity
echo "Retrieving storage account key using managed identity..."
STORAGE_KEY=$(az storage account keys list \
    --account-name "$STORAGE_ACCOUNT_NAME" \
    --query '[0].value' \
    --output tsv)

if [ -z "$STORAGE_KEY" ]; then
    echo "ERROR: Failed to retrieve storage account key"
    exit 1
fi

# Create credentials file  
sudo bash -c "cat > /etc/azure-files-credentials <<EOF
username=$STORAGE_ACCOUNT_NAME
password=$STORAGE_KEY
EOF"
sudo chmod 600 /etc/azure-files-credentials

# Mount the share
UNC_PATH="//$STORAGE_ACCOUNT_NAME.file.core.windows.net/$SHARE_NAME"
sudo mount -t cifs "$UNC_PATH" "$MOUNT_POINT" -o "$MOUNT_OPTIONS"

# Verify and set permissions
if mountpoint -q "$MOUNT_POINT"; then
    sudo chown azureuser:azureuser "$MOUNT_POINT"
    echo "Mount successful at $MOUNT_POINT"
    
    if [ "$MAKE_PERSISTENT" = "true" ]; then
        sudo sed -i "\|$MOUNT_POINT|d" /etc/fstab
        echo "$UNC_PATH $MOUNT_POINT cifs $MOUNT_OPTIONS 0 0" | sudo tee -a /etc/fstab
    fi
else
    echo "Mount failed"
    exit 1
fi