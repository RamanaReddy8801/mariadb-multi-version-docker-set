#!/bin/bash

#############################################
# Load Environment Variables from .env
# This script is sourced by other scripts to load credentials
#############################################

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Path to .env file
ENV_FILE="$SCRIPT_DIR/.env"

# Check if .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  Warning: .env file not found!"
    echo "Creating .env from .env.example..."
    
    if [ -f "$SCRIPT_DIR/.env.example" ]; then
        cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
        echo "✓ Created .env file. You can customize the values if needed."
    else
        echo "❌ Error: .env.example not found!"
        exit 1
    fi
fi

# Load environment variables from .env
export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)

# Verify required variables are set
if [ -z "$MARIADB_10_ROOT_PASSWORD" ]; then
    echo "❌ Error: Required environment variables not loaded from .env"
    exit 1
fi

# Success indicator (optional, for debugging)
# echo "✓ Environment variables loaded from .env"
