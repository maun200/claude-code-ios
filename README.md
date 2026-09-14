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
dpkg -i claude-code_2.1.112-1_iphoneos-arm64.deb
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
- ~120MB storage
- zsh, ldid, ripgrep, git (git is needed by Claude Code's own plugin
  marketplace feature, not by this package itself)

## Package Contents

- `/var/jb/usr/local/bin/claude` - Main CLI wrapper
- `/var/jb/usr/local/bin/claude-auth` - Deprecation notice pointing at `claude`/`claude setup-token` (kept only so the old command doesn't just vanish)
- `/var/jb/usr/local/lib/claude-code/` - Node.js runtime + Claude Code

There is no `/var/jb/Applications/ClaudeCode.app/` anymore. It was a launcher
that just shelled out to `newterm3://run?command=...` - if NewTerm 3 wasn't
installed with that exact URL scheme it did nothing, so it added no real
functionality and has been removed.

## What changed since the original 2.1.19-1 release

- **Upgraded Claude Code itself from 2.1.19 to 2.1.112** - plugins, plugin
  marketplaces, custom agents, `--mcp-config`, skills, `--bare` mode, and
  everything else that shipped in that range. See "Why Claude Code is
  pinned to 2.1.112" below for why that specific version is the ceiling.
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
- **Added `git` to `Depends`.** Claude Code's plugin marketplace feature
  shells out to `git` to clone marketplace/plugin repos.
- **Sensible UTF-8/locale defaults for both `root` and `mobile`.** iOS
  jailbreak userlands ship no locale database at all, so `LANG`/`LC_ALL`
  are exported as a UTF-8 hint even though no real ICU locale backs them,
  and `HOME` now defaults correctly for whichever user runs `claude`
  (`/var/jb/var/root` vs `/var/jb/var/mobile`) instead of always assuming
  `mobile`.

See [`CHANGELOG.md`](CHANGELOG.md) for the full version history.

## Why Claude Code is pinned to 2.1.112

Anthropic changed how `@anthropic-ai/claude-code` is distributed partway
through its 2.1.x line:

- **Up to and including 2.1.112**, the npm package is a portable `cli.js`
  (plus a few native helper modules under `vendor/`) that runs under any
  Node.js binary satisfying `engines.node` - which is exactly what let
  this repo bundle its own iOS-patched Node 18.20.4 build (the JIT
  restrictions iOS enforces need a Node built and V8-flagged specifically
  for that) and run Anthropic's unmodified `cli.js` on top of it.
- **Starting at 2.1.113**, the npm package became a thin installer that
  downloads/links a *compiled native executable* for one of a fixed set of
  platforms (`darwin-arm64`, `darwin-x64`, `linux-x64`/`arm64`
  (+musl), `win32-x64`/`arm64`) - there is no Node.js runtime involved at
  all anymore, and no `ios-arm64` (or any generic/portable) target exists.
  iOS reports `darwin`/`arm64`, so the installer would fetch the
  **real-macOS** `darwin-arm64` binary, which will not run on iOS.

So 2.1.112 is the newest version this packaging approach can support at
all - not a conservative choice, a hard ceiling given how upstream ships
newer releases. `scripts/build-repack.sh` fetches it directly from the npm
registry at build time (checksum-pinned in
`scripts/claude-code-npm.sha256`) rather than checking its source into
git. If Anthropic ever ships a portable/iOS-targeted build again, or a
community iOS build of the newer native binary shows up, bumping past
2.1.112 means updating that one pinned checksum + version, not touching
the overlay.

## Building this package (maintainers)

This repo does **not** check in the extracted Claude Code/Node.js sources.
Instead:

- `debs/claude-code_2.1.19-1_iphoneos-arm64.deb` is kept as the pinned
  upstream base package - the source of the iOS-patched `node` binary,
  `entitlements.xml`, and `segmenter-shim.js`. Checksum pinned in
  [`scripts/base-deb.sha256`](scripts/base-deb.sha256).
- The actual Claude Code CLI (`cli.js` + `vendor/`) is fetched fresh from
  the npm registry at build time and checksum-pinned in
  [`scripts/claude-code-npm.sha256`](scripts/claude-code-npm.sha256)
  (cached under `.build-cache/`, which is gitignored, so repeat builds
  don't re-download it).
- Every released `.deb` is produced by taking the base package, dropping
  in that CLI tarball, and overlaying a small set of tracked files on top:

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

`build-repack.sh` refuses to run if the base `.deb` or the fetched CLI
tarball doesn't match its pinned checksum, and produces byte-for-byte
reproducible output for the same inputs (see `tests/test_repack_build.sh`).
It needs network access (to fetch the pinned npm tarball, unless already
cached) but nothing else.

To bump the bundled CLI version, update the URL/checksum in
`scripts/claude-code-npm.sha256` and the `Version:`/description in
`overlay/control/control` - see "Why Claude Code is pinned to 2.1.112"
below before doing that, since anything past 2.1.112 needs a different
distribution model entirely, not just a version bump.

## Tests

```bash
tests/run-tests.sh
```

Two suites, no device or network access needed:

- `tests/test_overlay_wrapper.sh` - content checks on the overlay wrapper
  scripts (no credential gate, no OAuth server, required env vars present).
- `tests/test_repack_build.sh` - builds a real `.deb` from the pinned base
  package + the pinned CLI tarball + the overlay, then inspects it with
  `dpkg-deb`/`tar` (no `ClaudeCode.app`, `ripgrep`/`git` dependencies
  present, CLI version upgraded, reproducible build, checksum verification
  enforced for both pinned inputs). Needs network access the first time
  (to populate `.build-cache/`).

## Known limitations

- The official CLI's own login flow (`/login`, `claude setup-token`) has
  been exercised on-device for startup only; a full interactive OAuth round
  trip needs a real user with a Claude account and wasn't run end-to-end as
  part of this change.
- `USE_BUILTIN_RIPGREP=1` assumes the `ripgrep` dependency is actually
  installed; if you install this .deb with a package manager that ignores
  `Depends` (e.g. a raw `dpkg -i` without `apt`/`Sileo` resolving it), you
  must install `ripgrep` (and `git`, for the plugin marketplace) yourself.
- Voice input (`vendor/audio-capture`) is a native module built for real
  macOS, not iOS - it's still shipped (in case it partially works) but the
  CLI treats it as optional and disables voice input if it fails to load,
  so this is a missing feature, not a crash.
- The new `vendor/seccomp` sandboxing helper is Linux-only by design
  (macOS/iOS use a different, native sandboxing mechanism); it isn't
  expected to be used on iOS at all.
- The plugin/marketplace *install* flow specifically (which needs `git`
  and network access to a real marketplace repo) was not exercised
  end-to-end - see the PR description for exactly what was and wasn't
  tested live on-device.

## License

Claude Code is proprietary software by Anthropic. This package is for personal use on jailbroken devices.
