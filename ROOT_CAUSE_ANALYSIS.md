# Root Cause Analysis: Files Being Modified on Cursor Open

## The Problem

Files show as modified in git every time Cursor is opened, even though:
- `.editorconfig` has been removed
- All auto-formatting is disabled in VS Code settings
- EditorConfig extension is not installed

## What We Know

1. **Files ARE actually different** - `git update-index --refresh` says "needs update"
2. **Extra newlines are being added** - Files in git have 4 trailing newlines, working directory has 6
3. **This started recently** - You've used Cursor for 12+ months without this issue
4. **`.editorconfig` was recently added** - In commit `af5caf1` ("Format code: Apply Dart formatter to all files")

## Possible Root Causes

### 1. Cursor's Built-in EditorConfig Support (Most Likely)

VS Code/Cursor has **built-in** EditorConfig support (not an extension). Even after removing `.editorconfig`, Cursor may have:
- Cached the EditorConfig rules in workspace state
- Stored settings in `~/.config/Cursor/User/workspaceStorage/`
- Applied rules from a parent directory's `.editorconfig`

### 2. File System or Git Configuration

- Git's `core.autocrlf` or line ending normalization
- File system events triggering git to re-check files
- Git index getting out of sync with actual file contents

### 3. Cursor-Specific Behavior

- Cursor may have different defaults than VS Code
- Workspace-level settings overriding project settings
- File watchers modifying files on read

## Solutions to Try

### Solution 1: Clear Cursor's Workspace Cache

```bash
# Close Cursor completely first
rm -rf ~/.config/Cursor/User/workspaceStorage/*
# Or find your specific project folder and delete just that
```

### Solution 2: Check for Parent Directory .editorconfig

```bash
# Check if there's an .editorconfig in a parent directory
find ~/Workdir -name ".editorconfig" -type f
```

### Solution 3: Check Git Configuration

```bash
git config --list | grep -E "(autocrlf|eol|core\.)"
# Should show: core.autocrlf=input (for Linux)
```

### Solution 4: Verify Files Are Actually Different

```bash
# Compare file in git vs working directory
git show HEAD:.gitattributes | wc -c
wc -c < .gitattributes
# If different, files ARE being modified
```

## Current Status

- ✅ `.editorconfig` removed
- ✅ All auto-formatting disabled in `.vscode/settings.json`
- ✅ `[*]` wildcard added to disable formatting for all file types
- ✅ Auto-save disabled
- ❌ Files still being modified when Cursor opens them

## Next Steps

1. **Clear Cursor's workspace cache** (Solution 1)
2. **Check for parent directory `.editorconfig`** (Solution 2)
3. **If still happening, it may be Cursor-specific behavior** that can't be disabled

The fact that `git update-index --refresh` says "needs update" confirms files ARE being modified, not just a git index issue.

