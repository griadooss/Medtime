#!/bin/bash
#
# Setup script to install git hooks
# Run this after cloning the repository to enable pre-commit formatting

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Setting up git hooks..."

# Copy pre-commit hook
if [ -f "$REPO_ROOT/.git/hooks/pre-commit" ]; then
  echo "Pre-commit hook already exists. Overwriting..."
fi

cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/sh
#
# Pre-commit hook to format Dart files before committing
# This ensures all code is consistently formatted

# Get the list of staged Dart files
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.dart$')

if [ -z "$STAGED_DART_FILES" ]; then
  # No Dart files staged, nothing to format
  exit 0
fi

echo "Running Dart formatter on staged files..."

# Format the staged Dart files
dart format $STAGED_DART_FILES

# Stage the formatted files (in case formatting changed them)
git add $STAGED_DART_FILES

echo "Dart formatting complete."
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ Pre-commit hook installed successfully!"
echo ""
echo "The hook will automatically format Dart files before each commit."

