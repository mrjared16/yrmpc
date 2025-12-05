#!/bin/bash
mkdir -p ~/.config/rmpc

# Copy config
if [ -f ~/.config/rmpc/config.ron ]; then
    read -p "~/.config/rmpc/config.ron already exists. Overwrite? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp setup/config.ron ~/.config/rmpc/config.ron
        echo "Overwrote ~/.config/rmpc/config.ron"
    else
        echo "Skipped config.ron"
    fi
else
    cp setup/config.ron ~/.config/rmpc/config.ron
    echo "Created ~/.config/rmpc/config.ron"
fi

# Copy auth template
if [ ! -f ~/.config/rmpc/headers_auth.json ]; then
    cp setup/headers_auth.json.template ~/.config/rmpc/headers_auth.json
    echo "Created ~/.config/rmpc/headers_auth.json (template)"
else
    echo "~/.config/rmpc/headers_auth.json already exists. Keeping it."
fi

echo ""
echo "SETUP COMPLETE!"
echo "----------------------------------------------------------------"
echo "IMPORTANT: You MUST edit ~/.config/rmpc/headers_auth.json"
echo "and paste your YouTube Music cookies there."
echo "----------------------------------------------------------------"
echo "Then run: ./rmpc/target/release/rmpc"
