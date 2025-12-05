#!/bin/bash

# Check if cookies file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_cookies.txt>"
    echo "Example: $0 ~/Downloads/cookies.txt"
    exit 1
fi

COOKIE_FILE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/parse_cookies.py"
TARGET_AUTH_FILE="$HOME/.config/rmpc/headers_auth.json"

# Check if python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: parse_cookies.py not found in $SCRIPT_DIR"
    exit 1
fi

# Check if cookies file exists
if [ ! -f "$COOKIE_FILE" ]; then
    echo "Error: Cookies file not found: $COOKIE_FILE"
    exit 1
fi

# Run the python script
echo "Parsing cookies from $COOKIE_FILE..."
python3 "$PYTHON_SCRIPT" "$COOKIE_FILE" "$TARGET_AUTH_FILE"

if [ $? -eq 0 ]; then
    echo "✅ Successfully updated $TARGET_AUTH_FILE"
    echo "You can now restart rmpc."
else
    echo "❌ Failed to update auth file."
    exit 1
fi
