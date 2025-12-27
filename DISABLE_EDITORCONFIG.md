# How to Stop Files from Being Auto-Modified in Cursor

If you're seeing files show as modified every time you open Cursor, it's likely the **EditorConfig extension** automatically applying formatting rules.

## ✅ RECOMMENDED: Disable EditorConfig Extension

**This is the most reliable solution.** Since you've been using Cursor for 12+ months without this issue, the EditorConfig extension was likely recently installed or updated.

### Steps:
1. Open Cursor
2. Press `Ctrl+Shift+X` (or `Cmd+Shift+X` on Mac) to open Extensions
3. Search for "EditorConfig"
4. Find "EditorConfig for VS Code" by EditorConfig
5. Click **Disable** (or **Uninstall** if you don't need it)
6. Reload Cursor (`Ctrl+Shift+P` → "Reload Window")

### Why This is Safe:
- Your VS Code settings already handle formatting (`files.insertFinalNewline`, `files.trimTrailingWhitespace`)
- Your pre-commit hook formats Dart files automatically
- The Dart formatter handles all Dart code formatting
- The `.editorconfig` file will still exist (other tools can read it)

## Alternative: Auto-Commit Whitespace Changes

If you want to keep EditorConfig but auto-commit these harmless changes:

```bash
# Run this script whenever files show as modified:
./scripts/fix-editorconfig-changes.sh

# Or create a git alias:
git config alias.fix-whitespace '!f() { git add -u && git commit -m "Auto-format: EditorConfig whitespace changes"; }; f'
# Then use: git fix-whitespace
```

## Why This Happens

The EditorConfig extension reads `.editorconfig` and automatically applies rules like:
- `insert_final_newline = true` - Adds newline at end of files
- `trim_trailing_whitespace = true` - Removes trailing spaces

Even if files already comply, the extension may still modify them when opening files, regardless of VS Code settings.

## What We've Tried

We've configured:
- `editorconfig.generateAuto: false`
- `editorconfig.autoFixOnSave: true`
- `editorconfig.fixOnSave: true`

But the extension still applies rules on file open. **Disabling the extension is the only reliable solution.**


