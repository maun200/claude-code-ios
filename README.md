# Claude Code iOS Repository

Sileo/Cydia/Zebra repository for Claude Code on jailbroken iOS devices.

> **Note:** The home screen app launcher is experimental. Use the `claude` terminal command for reliable operation.

## Add Repository

Add this URL to your package manager:

```
https://imcynic.github.io/claude-code-ios/
```

## Manual Installation

Download the .deb from the [releases](debs/) and install via Filza or SSH:

```bash
dpkg -i claude-code_2.1.19-1_iphoneos-arm64.deb
```

## Usage

1. **Authenticate:**
   ```bash
   claude-auth
   ```

2. **Run Claude Code:**
   ```bash
   claude
   ```

## Requirements

- iOS 15.0+
- Jailbroken device (Dopamine, palera1n, etc.)
- ~150MB storage
- zsh, ldid

## Package Contents

- `/var/jb/usr/local/bin/claude` - Main CLI
- `/var/jb/usr/local/bin/claude-auth` - Authentication helper
- `/var/jb/usr/local/lib/claude-code/` - Node.js runtime + Claude Code
- `/var/jb/Applications/ClaudeCode.app/` - Home screen app

## License

Claude Code is proprietary software by Anthropic. This package is for personal use on jailbroken devices.
