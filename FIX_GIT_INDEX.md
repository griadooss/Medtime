# Fix: Files Showing as Modified When They're Not

## Root Cause

Git's index can get out of sync with actual file contents, especially when:
- Cursor/VS Code touches files (updates timestamps) when opening them
- File watchers trigger git to re-check files
- There are race conditions between file system and git

## Solution

If files show as modified but `git diff` shows no actual changes, run:

```bash
git update-index --refresh
```

This refreshes git's index with the actual file contents and should clear false "modified" reports.

## Automatic Fix

We've added git hooks that automatically refresh the index after:
- `git checkout` (post-checkout hook)
- `git merge` (post-merge hook)

## Manual Fix (if needed)

If files still show as modified after reopening Cursor:

1. Check if there are actual changes:
   ```bash
   git diff --ignore-all-space --ignore-blank-lines
   ```

2. If no actual changes, refresh the index:
   ```bash
   git update-index --refresh
   ```

3. Verify it's clean:
   ```bash
   git status
   ```

## Why This Happens

Cursor/VS Code may:
- Update file timestamps when opening files
- Trigger file system events that make git re-check files
- Have file watchers that cause git index to get out of sync

The `git update-index --refresh` command forces git to re-read the actual file contents and update its index, clearing false positives.



