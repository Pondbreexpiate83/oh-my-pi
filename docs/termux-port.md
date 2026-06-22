# Termux (Android) Setup

omp runs natively on Android via [Termux](https://termux.dev/). This
document covers the Android-specific install path. The `omp` build
targets **Android 14+** (kernel 5.15+) — earlier Android releases do
not expose the `pidfd_open` syscall that the `pi_natives` addon uses
for process-tree management.

## Install

```bash
# 1. Install Termux from F-Droid (the Play Store version is obsolete).
#    Also install Termux:API from F-Droid for clipboard bridge.

# 2. Run the installer:
curl -fsSL https://raw.githubusercontent.com/Pondbreexpiate83/oh-my-pi/android-port/scripts/install-termux.sh | sh
```

The installer:
1. Verifies `uname -m` is `aarch64` (other archs are not supported).
2. Installs `git`, `curl`, `unzip` via `pkg`.
3. Downloads `bun-linux-aarch64-android.zip` to `$PREFIX/bin/bun` if
   Bun is not already on `PATH`.
4. Clones the fork to `~/.local/share/oh-my-pi`.
5. Downloads the latest prebuilt `pi_natives.android-arm64.node` from
   the fork's GitHub Releases into the fork's `packages/natives/native/`
   directory.
6. Drops an `omp` wrapper at `$PREFIX/bin/omp`.
7. Copies `templates/AGENTS.md` to `~/.omp/agent/AGENTS.md`.

## Verify

```bash
omp --version
omp -p "echo hello"
omp                 # launches the TUI
```

## Known limits

- **Clipboard:** text is bridged via `termux-clipboard-set` /
  `termux-clipboard-get`. Image clipboard is not available.
- **Browser tool:** Puppeteer/Chromium is heavy on Android. The
  `browser` tool is gated off by default upstream and not enabled here.
- **`bun run` cwd bug:** under `/data/data` with unreadable ancestors,
  Bun may fail with `CouldntReadCurrentDirectory`. Run `omp` from a
  path with readable ancestors (e.g. `$HOME`).
- **Process tools:** `Process::from_pid` returns `None` on hosts that
  lack `pidfd_open` (Android < 14). Subagent kill-tree operations will
  silently no-op in that case.

## Updating

```bash
# Re-run the installer to fetch the latest prebuilt .node:
curl -fsSL https://raw.githubusercontent.com/Pondbreexpiate83/oh-my-pi/android-port/scripts/install-termux.sh | sh
```

## Uninstalling

```bash
rm -rf ~/.local/share/oh-my-pi
rm -f $PREFIX/bin/omp
rm -rf ~/.omp
```

## Source

- Fork: https://github.com/Pondbreexpiate83/oh-my-pi (branch `android-port`).
- Upstream: https://github.com/can1357/oh-my-pi
- Plan: `docs/superpowers/plans/2026-06-22-omp-termux-native.md`
- Spec: `docs/superpowers/specs/2026-06-22-omp-termux-native-design.md`
