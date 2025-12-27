#!/bin/bash
# Setup git hooks to auto-refresh index and prevent false "modified" file reports
# This fixes issues where Cursor/VS Code file operations cause git index to get out of sync

echo "Setting up git hooks to auto-refresh index..."

# Create post-checkout hook
cat > .git/hooks/post-checkout << 'EOF'
#!/bin/sh
# Refresh git index after checkout to prevent false "modified" file reports
git update-index --refresh
EOF

# Create post-merge hook
cat > .git/hooks/post-merge << 'EOF'
#!/bin/sh
# Refresh git index after merge to prevent false "modified" file reports
git update-index --refresh
EOF

# Make hooks executable
chmod +x .git/hooks/post-checkout .git/hooks/post-merge

echo "✓ Git hooks installed successfully"
echo ""
echo "These hooks will automatically run 'git update-index --refresh' after:"
echo "  - git checkout"
echo "  - git merge"
echo ""
echo "This prevents false 'modified' file reports when git index gets out of sync."

