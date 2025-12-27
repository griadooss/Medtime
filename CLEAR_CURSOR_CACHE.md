# How to Clear Cursor's Cached EditorConfig Settings

If files are still showing as modified after removing `.editorconfig`, Cursor may have cached the EditorConfig rules.

## Option 1: Clear Cursor's Workspace State

1. Close Cursor completely
2. Navigate to Cursor's storage location:
   - Linux: `~/.config/Cursor/User/workspaceStorage/`
   - Mac: `~/Library/Application Support/Cursor/User/workspaceStorage/`
   - Windows: `%APPDATA%\Cursor\User\workspaceStorage\`
3. Find the folder for your Medtime project (look for a hash/folder name)
4. Delete that folder (or just the `state.vscdb` file inside it)
5. Restart Cursor

## Option 2: Use the Auto-Commit Script

Since this is just whitespace changes, you can use the provided script:

```bash
./scripts/fix-editorconfig-changes.sh
```

This will automatically commit whitespace-only changes.

## Option 3: Create a Git Alias

```bash
git config alias.fix-whitespace '!f() { git add -u && git commit -m "Auto-format: whitespace changes"; }; f'
```

Then use: `git fix-whitespace` whenever files show as modified.

## Why This Happens

Even after removing `.editorconfig`, Cursor may have cached the rules in its workspace state. Clearing the cache forces Cursor to re-read the current project state without the `.editorconfig` file.

