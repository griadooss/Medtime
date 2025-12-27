#!/bin/bash
# Clear Cursor's workspace cache for this project
# This removes cached EditorConfig rules that may be causing file modifications

PROJECT_PATH=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")

echo "Clearing Cursor workspace cache for: $PROJECT_NAME"
echo "Project path: $PROJECT_PATH"
echo ""

CURSOR_STORAGE="$HOME/.config/Cursor/User/workspaceStorage"

if [ ! -d "$CURSOR_STORAGE" ]; then
    echo "❌ Cursor storage directory not found: $CURSOR_STORAGE"
    exit 1
fi

echo "Searching for workspace cache..."
FOUND=0

for dir in "$CURSOR_STORAGE"/*/; do
    if [ -d "$dir" ]; then
        # Check if this workspace matches our project
        if [ -f "$dir/workspace.json" ] && grep -q "$PROJECT_NAME\|$PROJECT_PATH" "$dir/workspace.json" 2>/dev/null; then
            echo "✓ Found workspace cache: $dir"
            echo "  Deleting cache..."
            rm -rf "$dir"
            FOUND=$((FOUND + 1))
        fi
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "⚠ No matching workspace cache found"
    echo "You may need to manually check: $CURSOR_STORAGE"
else
    echo ""
    echo "✓ Cleared $FOUND workspace cache(s)"
    echo ""
    echo "Next steps:"
    echo "1. Close Cursor completely"
    echo "2. Reopen Cursor and the project"
    echo "3. Check if files still show as modified"
fi

