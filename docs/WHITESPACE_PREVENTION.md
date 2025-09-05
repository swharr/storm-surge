# Whitespace Prevention Guide

This project includes multiple layers of protection against trailing whitespace and formatting issues that can cause CI failures.

## 🛡️ Automatic Prevention (Editor Level)

### VS Code
Settings are automatically applied from `.vscode/settings.json`:
- **Auto-trim on save**: Trailing whitespace is removed when you save
- **Auto-insert final newline**: Ensures files end with newline
- **Visual indicators**: Shows trailing whitespace as you type
- **Format on save**: Applies formatting automatically

No action needed - just save your files normally!

### Sublime Text
Open the project using `storm-surge.sublime-project`:
- **Auto-trim on save**: Enabled for all file types except Markdown
- **Final newline**: Automatically added on save
- **Build systems**: Press Cmd+B (Mac) or Ctrl+B (Windows/Linux) to:
  - Fix Whitespace
  - Run Tests
  - Run Pre-commit Check

For the Trailing Spaces package (recommended):
```bash
# Install Package Control, then install "Trailing Spaces" package
# Settings are auto-configured in .sublime/trailing_spaces.sublime-settings
```

### Other Editors
The `.editorconfig` file provides universal editor support. Most modern editors respect these settings automatically.

## 🔧 Manual Fixes

### Quick Fix Script
```bash
# Fix all whitespace issues in the project
./scripts/fix-whitespace.sh

# Or use the Makefile
make fix-whitespace
```

### Pre-commit Hook (Git Level)
Install the Git hook to auto-fix whitespace before commits:
```bash
make install-hooks
# Now whitespace is automatically fixed when you commit!
```

### Full Format & Check
```bash
# Format everything and run checks
make format

# Run all checks (whitespace, lint, tests)
make check
```

## 📋 Available Commands

```bash
make help              # Show all available commands
make fix-whitespace    # Fix trailing whitespace
make test             # Run all tests
make format           # Format all code
make lint             # Run linters
make check            # Run all checks
make ci               # Run CI pipeline locally
```

## 🚨 Troubleshooting

### Still getting whitespace errors?
1. **Pull latest changes**: Someone may have introduced whitespace
   ```bash
   git pull
   make fix-whitespace
   git add -A
   git commit -m "fix: remove trailing whitespace"
   ```

2. **Check your editor**: Ensure settings are loaded
   - VS Code: Check that `.vscode/settings.json` is applied
   - Sublime: Open via the `.sublime-project` file
   - Other: Verify `.editorconfig` support is enabled

3. **Nuclear option**: Fix everything at once
   ```bash
   # Fix whitespace, format code, run tests
   make check
   ```

### Pre-commit hook not working?
```bash
# Reinstall hooks
make install-hooks

# Or manually
git config core.hooksPath .githooks
```

## 🎯 Best Practices

1. **Use the project settings**: Open the project properly in your editor
2. **Save frequently**: Let auto-trim handle whitespace for you
3. **Run tests locally**: `make test` before pushing
4. **Install hooks**: `make install-hooks` once after cloning

## 📝 File-Specific Rules

- **Python** (`.py`): 4 spaces, trim whitespace
- **YAML** (`.yaml`, `.yml`): 2 spaces, trim whitespace
- **JSON** (`.json`): 2 spaces, trim whitespace
- **JavaScript/TypeScript**: 2 spaces, trim whitespace
- **Markdown** (`.md`): Preserve trailing spaces (used for line breaks)
- **Shell** (`.sh`): 2 spaces, trim whitespace

## 🔄 CI Integration

The CI pipeline will fail if trailing whitespace is detected. To match CI behavior locally:

```bash
# Run the same checks CI runs
make ci

# Or just the pre-commit hooks
pre-commit run --all-files
```

---

**Remember**: With these tools in place, whitespace issues should be automatically prevented. If you're seeing failures, something in your setup needs adjustment!