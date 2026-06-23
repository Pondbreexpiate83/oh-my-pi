# Agent Environment: Termux on Android

You are running inside [Termux](https://termux.dev/) on Android. The user
installed `omp` natively against Android's bionic libc — no proot, no
glibc-runner.

## Location

- **OS:** Android (Termux terminal emulator)
- **Architecture:** aarch64
- **Home:** `/data/data/com.termux/files/home`
- **Prefix:** `/data/data/com.termux/files/usr`
- **Shared storage:** `/storage/emulated/0` (Downloads, Documents, etc.)

## Toolchain

- **Bun:** `$PREFIX/bin/bun`. The prebuilt Bun for Termux is
  `bun-linux-aarch64-android`.
- **Native addon:** `~/.local/share/oh-my-pi/packages/natives/native/pi_natives.android-arm64.node`
  (built locally on the device by `scripts/build-termux.sh`).
- **Rust:** Termux's `pkg install rust` provides stable. The cross-compile
  for `aarch64-linux-android` is built in (no rustup needed).

## Native constraints

- **`arboard` (clipboard) is NOT linked.** The native addon returns an
  error if asked to copy text directly. Use `termux-clipboard-set` and
  `termux-clipboard-get` via the `bash` tool, with the **Termux:API** app
  installed.
- **PTY:** uses `portable-pty` against bionic's termios. `sh`, `bash`,
  and other POSIX shells are available.
- **`/proc`:** readable. `pidfd_open` / `pidfd_send_signal` require
  **Android 14+** (kernel 5.15+).
- **Filesystem:** avoid hardlinks; the kernel's `linkat` on cross-FS
  paths returns EPERM. Use `cp -al` only inside the same filesystem.
- **Memory:** phones have 4-8 GB total. The addon avoids `lto="fat"`
  for this reason; long subprocess pipelines may still OOM.

## Installation context

- `omp` is a wrapper at `$PREFIX/bin/omp` (typically
  `/data/data/com.termux/files/usr/bin/omp`).
- The fork at `~/.local/share/oh-my-pi` is shallow-cloned from
  `Pondbreexpiate83/oh-my-pi` branch `android-direct`.
- The native addon is **built on the device** by `scripts/build-termux.sh`
  (30-60 min). There is no prebuilt binary.

## Known limits (vs upstream)

- `clipboard` text is bridged via `termux-clipboard-set` /
  `termux-clipboard-get`. Image clipboard is unavailable.
- `browser` tool (Puppeteer/Chromium) is heavy on Android; gated off
  by default upstream.
- The TUI may briefly show a "failed to read current directory" warning
  when launched from a path with unreadable ancestors. Workaround: cd
  to a readable path first.
- `Process::from_pid` returns `None` on Android < 14. The addon still
  loads, but process-tree operations silently no-op.

## See also

- `docs/termux-port.md` in the fork for installation, troubleshooting,
  and release notes.
