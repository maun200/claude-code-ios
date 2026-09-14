# Changelog

## 2.1.19-2

- Removed the home-screen app (`/var/jb/Applications/ClaudeCode.app`) - it
  was just a broken NewTerm URL-scheme launcher with no functionality of
  its own.
- Removed the bundled OAuth/localhost-callback flow and the credential gate
  in `claude`/`claude-auth`. Login and onboarding are now entirely the
  official Claude Code CLI's responsibility (`/login`, or
  `claude setup-token` for headless SSH sessions). `claude-auth` is kept
  only as a short deprecation notice.
- Fixed a terminal hang on first launch on several iOS terminal apps by
  exporting `CLAUDE_CODE_ACCESSIBILITY=1` in the wrapper.
- Switched to the system `ripgrep` package (`USE_BUILTIN_RIPGREP=1`)
  instead of the bundled macOS `ripgrep.node`, and added `ripgrep` to
  `Depends`.
- Added sensible UTF-8 locale defaults (`LANG`/`LC_ALL`/`LC_CTYPE`) and
  fixed `HOME` detection so the wrapper works correctly for both `root`
  (SSH sessions) and `mobile` (normal terminal apps).
- Rebuilt as a traceable overlay/repack on top of the pinned upstream
  2.1.19-1 `.deb` (`scripts/build-repack.sh`) instead of checking in
  extracted proprietary sources.

## 2.1.19-1

- Initial iOS release.
- Node.js 18.20.4 with iOS optimizations.
- Home screen app launcher.
- OAuth and API key authentication.
- Rootless jailbreak support (`/var/jb`).
