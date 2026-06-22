# Agent Environment: Termux on Android

You are running inside [Termux](https://termux.dev/) on Android. The user
installed omp natively against Android's bionic libc — no proot, no
glibc-runner.

## Location

- **OS:** Android (Termux terminal emulator)
- **Architecture:** aarch64
- **Home:** `/data/data/com.termux/files/home`
- **Prefix:** `/data/data/com.termux/files/usr`
- **Shared storage:** `/storage/emulated/0` (Downloads, Documents, etc.)

## Toolchain

- **Bun:** `~/.local/bin/bun` (or `$PREFIX/bin/bun`). The prebuilt
  Bun for Termux is `bun-linux-aarch64-android`.
- **Native addon:** `~/.local/share/oh-my-pi/packages/natives/native/pi_natives.android-arm64.node`
- **Rust (if installed via pkg):** stable only — the prebuilt `pi_natives`
  for Android 14+ uses no nightly features.

## Native constraints

- **`arboard` (clipboard) is not linked.** Use `termux-clipboard-set` and
  `termux-clipboard-get` via the `bash` tool, with the Termux:API app
  installed. The native addon returns an error if asked to copy text
  directly; do not retry the same path.
- **PTY:** uses `portable-pty` against bionic's termios. `sh`, `bash`,
  and other POSIX shells are available.
- **`/proc`:** fully readable. `pidfd_open` / `pidfd_send_signal`
  require Android 14+ (kernel 5.15+).
- **Filesystem:** avoid hardlinks; `cc-rs` and Bun's `bun install` may
  require `BUN_OPTIONS="--os=android"` if you are building native
  Node modules from scratch.

## Installation context

- `omp` is a wrapper at `$PREFIX/bin/omp` (typically
  `/data/data/com.termux/files/usr/bin/omp`).
- The fork at `~/.local/share/oh-my-pi` is shallow-cloned and tracks
  `origin` (the `Pondbreexpiate83/oh-my-pi` fork).
- The native addon is downloaded from the latest GitHub release of the
  fork; re-run the installer to upgrade.

## See also

- `docs/termux-port.md` in the fork for installation, troubleshooting, and
  release notes.
