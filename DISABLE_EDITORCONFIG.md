# How to Stop Files from Being Auto-Modified in Cursor

If you're seeing files show as modified every time you open Cursor, it's likely the **EditorConfig extension** automatically applying formatting rules.

## Quick Fix: Disable EditorConfig Extension

1. Open Cursor
2. Press `Ctrl+Shift+X` (or `Cmd+Shift+X` on Mac) to open Extensions
3. Search for "EditorConfig"
4. Find "EditorConfig for VS Code" by EditorConfig
5. Click **Disable** (or **Uninstall** if you don't need it)

## Alternative: Keep EditorConfig but Disable Auto-Fix

If you want to keep EditorConfig but stop it from auto-modifying files:

1. Open Settings (`Ctrl+,` or `Cmd+,`)
2. Search for "editorconfig"
3. Uncheck "EditorConfig: Auto Fix On Save"
4. Set "EditorConfig: Generate Auto" to false

## Why This Happens

The EditorConfig extension reads `.editorconfig` and automatically applies rules like:
- `insert_final_newline = true` - Adds newline at end of files
- `trim_trailing_whitespace = true` - Removes trailing spaces

Even if files already comply, the extension may still modify them when opening.

## Current Settings

We've already configured:
- `editorconfig.generateAuto: false`
- `editorconfig.autoFixOnSave: false`

But the extension may still apply rules on file open. Disabling the extension is the most reliable solution.

