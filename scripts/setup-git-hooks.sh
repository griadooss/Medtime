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
# Pre-commit hook to format files before committing
# This ensures all code is consistently formatted

# Get all staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

FORMATTED_FILES=""

# Format Dart files (always available in Flutter projects)
STAGED_DART_FILES=$(echo "$STAGED_FILES" | grep '\.dart$')
if [ -n "$STAGED_DART_FILES" ]; then
  echo "Formatting Dart files..."
  dart format $STAGED_DART_FILES
  FORMATTED_FILES="$FORMATTED_FILES $STAGED_DART_FILES"
fi

# Format JSON files (if jq is available)
if command -v jq >/dev/null 2>&1; then
  STAGED_JSON_FILES=$(echo "$STAGED_FILES" | grep '\.json$')
  if [ -n "$STAGED_JSON_FILES" ]; then
    echo "Formatting JSON files..."
    for json_file in $STAGED_JSON_FILES; do
      # Skip if file doesn't exist or is binary
      if [ -f "$json_file" ] && file "$json_file" | grep -q "text"; then
        jq . "$json_file" > "$json_file.tmp" && mv "$json_file.tmp" "$json_file" 2>/dev/null
        FORMATTED_FILES="$FORMATTED_FILES $json_file"
      fi
    done
  fi
fi

# Format YAML files (if yamlfmt is available)
if command -v yamlfmt >/dev/null 2>&1; then
  STAGED_YAML_FILES=$(echo "$STAGED_FILES" | grep -E '\.(yaml|yml)$')
  if [ -n "$STAGED_YAML_FILES" ]; then
    echo "Formatting YAML files..."
    yamlfmt $STAGED_YAML_FILES
    FORMATTED_FILES="$FORMATTED_FILES $STAGED_YAML_FILES"
  fi
fi

# Format Markdown files (if prettier is available)
if command -v prettier >/dev/null 2>&1; then
  STAGED_MD_FILES=$(echo "$STAGED_FILES" | grep '\.md$')
  if [ -n "$STAGED_MD_FILES" ]; then
    echo "Formatting Markdown files..."
    prettier --write $STAGED_MD_FILES
    FORMATTED_FILES="$FORMATTED_FILES $STAGED_MD_FILES"
  fi
fi

# Stage all formatted files
if [ -n "$FORMATTED_FILES" ]; then
  git add $FORMATTED_FILES
  echo "Formatting complete."
fi
EOF

chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ Pre-commit hook installed successfully!"
echo ""
echo "The hook will automatically format Dart files before each commit."

