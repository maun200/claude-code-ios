# Claude Code iOS Repository

Sileo/Cydia/Zebra repository for Claude Code on jailbroken iOS devices.

This package is a **CLI-only** repack: there is no home-screen app. Run it
from a terminal (SSH, NewTerm, etc.) with the `claude` command.

## Add Repository

Add this URL to your package manager:

```
https://imcynic.github.io/claude-code-ios/
```

## Manual Installation

Download the .deb from [`debs/`](debs/) and install via Filza or SSH:

```bash
dpkg -i claude-code_2.1.19-2_iphoneos-arm64.deb
```

## Usage

```bash
claude
```

The first run walks you through the official CLI's own login (`/login`
inside the app). Over SSH with no browser handy, use a headless login
instead:

```bash
claude setup-token
```

Existing credentials in `~/.claude` from a previous install are left alone
and keep working.

## Requirements

- iOS 15.0+
- Jailbroken device (Dopamine, palera1n, etc.)
- ~140MB storage
- zsh, ldid, ripgrep

## Package Contents

- `/var/jb/usr/local/bin/claude` - Main CLI wrapper
- `/var/jb/usr/local/bin/claude-auth` - Deprecation notice pointing at `claude`/`claude setup-token` (kept only so the old command doesn't just vanish)
- `/var/jb/usr/local/lib/claude-code/` - Node.js runtime + Claude Code

There is no `/var/jb/Applications/ClaudeCode.app/` anymore. It was a launcher
that just shelled out to `newterm3://run?command=...` - if NewTerm 3 wasn't
installed with that exact URL scheme it did nothing, so it added no real
functionality and has been removed.

## What changed in 2.1.19-2

- **Removed the home-screen app.** It was a broken NewTerm URL-scheme
  launcher with no functionality of its own.
- **Removed the bundled OAuth/localhost-callback flow and the credential
  gate.** The old `claude-auth` ran its own PKCE/OAuth server on
  `127.0.0.1:19283` with a hardcoded client id, and the `claude` wrapper
  refused to start at all without a credentials file. Both duplicated (and
  had drifted out of sync with) the login flow the official CLI already
  ships. `claude-auth` is now a short pointer to `claude` (which has its
  own `/login`) and `claude setup-token` (for headless SSH sessions).
- **Fixed the initial-launch hang on iOS terminal apps.** The wrapper now
  sets `CLAUDE_CODE_ACCESSIBILITY=1`, which tells the CLI to skip
  cursor-visibility escape sequences that several iOS terminal apps don't
  handle correctly - without it, the first keypress could get "stuck" until
  Esc was pressed.
- **Switched to the system `ripgrep` package.** The bundled
  `vendor/ripgrep/arm64-darwin/ripgrep.node` is a macOS binary and cannot
  load on iOS. The wrapper now sets `USE_BUILTIN_RIPGREP=1`, which makes the
  CLI use the `rg` on `PATH` instead, and `ripgrep` was added to `Depends`.
  The bundled files are still shipped (harmless) as a fallback if you
  explicitly set `USE_BUILTIN_RIPGREP=0`.
- **Sensible UTF-8/locale defaults for both `root` and `mobile`.** iOS
  jailbreak userlands ship no locale database at all, so `LANG`/`LC_ALL`
  are exported as a UTF-8 hint even though no real ICU locale backs them,
  and `HOME` now defaults correctly for whichever user runs `claude`
  (`/var/jb/var/root` vs `/var/jb/var/mobile`) instead of always assuming
  `mobile`.

See [`CHANGELOG.md`](CHANGELOG.md) for the full version history.

## Building this package (maintainers)

This repo does **not** check in the extracted Claude Code/Node.js sources.
Instead, `debs/claude-code_2.1.19-1_iphoneos-arm64.deb` is kept as the
pinned upstream base package (its checksum is recorded in
[`scripts/base-deb.sha256`](scripts/base-deb.sha256)), and every released
`.deb` is produced by overlaying a small set of tracked files on top of it:

```
overlay/
  control/
    control    - the new package's control file (version, Depends, ...)
    postinst    - post-install script (no more app signing/uicache)
  data/
    var/jb/usr/local/bin/claude       - the wrapper script
    var/jb/usr/local/bin/claude-auth  - the deprecation stub
```

To rebuild:

```bash
scripts/build-repack.sh          # writes debs/claude-code_<version>_iphoneos-arm64.deb
scripts/generate-packages.sh     # regenerates Packages/.gz/.bz2/.xz from debs/*.deb
```

`build-repack.sh` refuses to run if the base `.deb` doesn't match the pinned
checksum, and produces byte-for-byte reproducible output for the same
inputs (see `tests/test_repack_build.sh`).

## Tests

```bash
tests/run-tests.sh
```

Two suites, no device or network access needed:

- `tests/test_overlay_wrapper.sh` - content checks on the overlay wrapper
  scripts (no credential gate, no OAuth server, required env vars present).
- `tests/test_repack_build.sh` - builds a real `.deb` from the pinned base
  package and the overlay, then inspects it with `dpkg-deb`/`tar` (no
  `ClaudeCode.app`, `ripgrep` dependency present, version bumped,
  reproducible build, checksum verification enforced).

## Known limitations

- The official CLI's own login flow (`/login`, `claude setup-token`) has
  been exercised on-device for startup only; a full interactive OAuth round
  trip needs a real user with a Claude account and wasn't run end-to-end as
  part of this change.
- `USE_BUILTIN_RIPGREP=1` assumes the `ripgrep` dependency is actually
  installed; if you install this .deb with a package manager that ignores
  `Depends` (e.g. a raw `dpkg -i` without `apt`/`Sileo` resolving it), you
  must install `ripgrep` yourself.

## License

Claude Code is proprietary software by Anthropic. This package is for personal use on jailbroken devices.
