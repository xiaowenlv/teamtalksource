#!/bin/bash

# OpenWrt 23.05 Build Environment Setup and Package Compilation Script
# This script sets up an OpenWrt SDK environment on Ubuntu/Debian VPS,
# downloads the x86_64 SDK for OpenWrt 23.05, installs dependencies,
# clones the luci-app-teamtalk package from a provided Git URL,
# and compiles only that package.
# All operations are unattended, with logging and error handling.

set -e  # Exit on any error

# Configuration
OPENWRT_VERSION="24.10"
SDK_URL="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-sdk-${OPENWRT_VERSION}-x86-64_gcc-13.2.0_musl.Linux-x86_64.tar.xz"
SDK_FILE="$(basename "$SDK_URL")"
LOG_FILE="openwrt_setup.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Check arguments
if [ $# -ne 1 ]; then
    error_exit "Usage: $0 <git_url_to_package_repo>"
fi

GIT_URL="$1"

log "Starting OpenWrt build environment setup for luci-app-teamtalk"

# Step 1: Update system
log "Step 1: Updating system packages..."
sudo apt update >> "$LOG_FILE" 2>&1 || error_exit "Failed to update system packages"
sudo apt upgrade -y >> "$LOG_FILE" 2>&1 || error_exit "Failed to upgrade system packages"

# Step 2: Install dependencies
log "Step 2: Installing build dependencies..."
sudo apt install -y \
    build-essential \
    libncurses-dev \
    zlib1g-dev \
    libssl-dev \
    libffi-dev \
    python3-dev \
    python3-pip \
    git \
    subversion \
    flex \
    bison \
    gawk \
    gettext \
    unzip \
    wget \
    curl \
    rsync \
    >> "$LOG_FILE" 2>&1 || error_exit "Failed to install dependencies"

# Step 3: Download OpenWrt SDK
log "Step 3: Downloading OpenWrt ${OPENWRT_VERSION} x86_64 SDK..."
wget "$SDK_URL" >> "$LOG_FILE" 2>&1 || error_exit "Failed to download SDK from $SDK_URL"

# Step 4: Extract SDK
log "Step 4: Extracting SDK..."
tar -xf "$SDK_FILE" >> "$LOG_FILE" 2>&1 || error_exit "Failed to extract SDK"
SDK_DIR="$(tar -tf "$SDK_FILE" | head -1 | cut -d'/' -f1)"
log "SDK extracted to directory: $SDK_DIR"

# Step 5: Clone package repository
log "Step 5: Cloning package repository from $GIT_URL..."
git clone "$GIT_URL" temp_package >> "$LOG_FILE" 2>&1 || error_exit "Failed to clone repository from $GIT_URL"

# Step 6: Update LuCI feeds in SDK
log "Step 6: Updating LuCI feeds in SDK..."
cd "$SDK_DIR" || error_exit "Failed to change to SDK directory"
./scripts/feeds update luci >> "$LOG_FILE" 2>&1 || error_exit "Failed to update luci feeds"
./scripts/feeds install -a -p luci >> "$LOG_FILE" 2>&1 || error_exit "Failed to install luci packages"

# Step 7: Copy package to SDK
log "Step 7: Copying luci-app-teamtalk package to SDK..."
cp -r ../temp_package/package/luci-app-teamtalk package/ >> "$LOG_FILE" 2>&1 || error_exit "Failed to copy package to SDK"

# Step 8: Compile the package
log "Step 8: Compiling luci-app-teamtalk package..."
make package/luci-app-teamtalk/compile V=s >> "$LOG_FILE" 2>&1 || error_exit "Failed to compile luci-app-teamtalk package"

# Cleanup
log "Cleaning up temporary files..."
cd ..
rm -rf temp_package "$SDK_FILE"

log "SUCCESS: OpenWrt build environment setup and package compilation completed successfully!"
log "Compiled package should be available in $SDK_DIR/bin/packages/x86_64/luci/"