# Git Hooks Setup

This directory contains scripts for setting up git hooks.

## Pre-commit Hook

The pre-commit hook automatically formats files before each commit to ensure consistent code style.

### Supported File Types

The hook formats the following file types (if the formatter is available):

1. **Dart files (`.dart`)** - Always formatted
   - Uses: `dart format` (built-in with Flutter SDK)
   - Required: Flutter SDK

2. **JSON files (`.json`)** - Optional
   - Uses: `jq` (JSON processor)
   - Install: `sudo pacman -S jq` (Arch/Manjaro) or `sudo apt install jq` (Ubuntu/Debian)

3. **YAML files (`.yaml`, `.yml`)** - Optional
   - Uses: `yamlfmt` (YAML formatter)
   - Install: `go install github.com/google/yamlfmt/cmd/yamlfmt@latest` (requires Go)

4. **Markdown files (`.md`)** - Optional
   - Uses: `prettier` (code formatter)
   - Install: `npm install -g prettier` (requires Node.js)

### Installation

Run the setup script to install the pre-commit hook:

```bash
./scripts/setup-git-hooks.sh
```

### How It Works

1. When you commit files, the hook runs automatically
2. It checks which file types are staged
3. For each file type, it checks if a formatter is available
4. If available, it formats the files
5. The formatted files are automatically staged
6. The commit proceeds with properly formatted code

### Notes

- **Dart formatting is always enabled** (Flutter SDK required)
- Other formatters are optional - if not installed, those file types are skipped
- The hook gracefully handles missing formatters
- Only staged files are formatted (not the entire repository)

### Installing Optional Formatters

If you want to format JSON, YAML, or Markdown files:

**JSON (jq):**
```bash
# Arch/Manjaro
sudo pacman -S jq

# Ubuntu/Debian
sudo apt install jq

# macOS
brew install jq
```

**YAML (yamlfmt):**
```bash
# Requires Go installed
go install github.com/google/yamlfmt/cmd/yamlfmt@latest
```

**Markdown (prettier):**
```bash
# Requires Node.js installed
npm install -g prettier
```

