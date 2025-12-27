#!/bin/bash
# Script to auto-commit EditorConfig whitespace-only changes
# Usage: ./scripts/fix-editorconfig-changes.sh

echo "Checking for whitespace-only changes..."

# Check if there are any changes
if ! git diff --quiet; then
    # Check if changes are whitespace-only
    if git diff -w --quiet; then
        echo "Found whitespace-only changes (likely EditorConfig auto-modifications)"
        echo "Committing these changes..."
        git add -u
        git commit -m "Auto-format: EditorConfig whitespace changes (final newlines, trailing whitespace)"
        echo "✓ Changes committed"
    else
        echo "⚠ Found non-whitespace changes. Please review manually:"
        git status --short
    fi
else
    echo "✓ No changes found"
fi



