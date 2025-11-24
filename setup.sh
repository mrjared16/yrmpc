#!/bin/bash
set -e

echo ">>> Installing Mopidy and extensions..."
# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "Error: 'yay' is not installed. Please install yay or use your preferred AUR helper."
    exit 1
fi

# Install dependencies
yay -S --needed mopidy mopidy-mpd mopidy-scrobbler python-ytmusicapi mopidy-youtube-git

echo ">>> Configuring Mopidy Cookie..."
# Ensure the target directory exists
sudo mkdir -p /var/lib/mopidy/.config/mopidy

# Centralized Cookie Location
CENTRAL_COOKIE="$HOME/.config/youtube-cookies.txt"
SOURCE_COOKIE="./music.youtube.com_cookies.txt"

echo ">>> Setting up Centralized Cookie at $CENTRAL_COOKIE..."

if [ -f "$SOURCE_COOKIE" ]; then
    # Backup existing if it's not a symlink to our source (edge case, but good practice)
    if [ -f "$CENTRAL_COOKIE" ] && [ ! -L "$CENTRAL_COOKIE" ]; then
        mv "$CENTRAL_COOKIE" "${CENTRAL_COOKIE}.bak"
        echo "Backed up existing centralized cookie to ${CENTRAL_COOKIE}.bak"
    fi
    
    cp "$SOURCE_COOKIE" "$CENTRAL_COOKIE"
    echo "Copied $SOURCE_COOKIE to $CENTRAL_COOKIE"
elif [ -f "$CENTRAL_COOKIE" ]; then
    echo "Using existing centralized cookie at $CENTRAL_COOKIE"
else
    echo "ERROR: No cookie found at $SOURCE_COOKIE and no existing centralized cookie."
    echo "Please export your cookies to $SOURCE_COOKIE"
    exit 1
fi

echo ">>> Configuring Mopidy Cookie..."
# Ensure the target directory exists
sudo mkdir -p /var/lib/mopidy/.config/mopidy

# Symlink the centralized cookie to Mopidy's location
echo "Linking $CENTRAL_COOKIE to /var/lib/mopidy/.config/mopidy/cookie.txt"
sudo ln -sf "$CENTRAL_COOKIE" /var/lib/mopidy/.config/mopidy/cookie.txt

# Also link for RMPC default location if needed
mkdir -p "$HOME/.config/rmpc"
ln -sf "$CENTRAL_COOKIE" "$HOME/.config/rmpc/cookie.txt"
echo "Linked $CENTRAL_COOKIE to $HOME/.config/rmpc/cookie.txt"

echo ">>> Installing Configuration Files..."
# Mopidy Config
mkdir -p "$HOME/.config/mopidy"
if [ -f "./config/mopidy.conf" ]; then
    ln -sf "$(pwd)/config/mopidy.conf" "$HOME/.config/mopidy/mopidy.conf"
    echo "Linked $(pwd)/config/mopidy.conf to $HOME/.config/mopidy/mopidy.conf"
fi

# RMPC Config
mkdir -p "$HOME/.config/rmpc"
if [ -f "./config/rmpc.toml" ]; then
    ln -sf "$(pwd)/config/rmpc.toml" "$HOME/.config/rmpc/config.toml"
    echo "Linked $(pwd)/config/rmpc.toml to $HOME/.config/rmpc/config.toml"
fi

echo ">>> Setup complete. Please restart Mopidy service if it's running."
# echo "sudo systemctl restart mopidy"
