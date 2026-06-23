# Termux (Android) Setup

`omp` runs natively on Android via [Termux](https://termux.dev/). This
document covers the Android-specific install path for the
`Pondbreexpiate83/oh-my-pi` fork, branch `android-direct`.

The `pi_natives` build targets **Android 14+** (kernel 5.15+) — earlier
Android releases do not expose the `pidfd_open` syscall that the
`pi_natives` addon uses for process-tree management.

## Requirements

- **Device:** Android 14+ on aarch64.
- **Termux:** install from F-Droid (NOT the Play Store version — it is
  obsolete and lacks required packages).
- **Termux:API:** install from F-Droid. Required for `termux-clipboard-set`
  / `termux-clipboard-get`.
- **Storage permission:** run `termux-setup-storage` once to grant access
  to `/storage/emulated/0`.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/Pondbreexpiate83/oh-my-pi/android-direct/scripts/install-termux.sh | sh
```

The installer:
1. Verifies `uname -m` is `aarch64` and `ro.build.version.release >= 14`.
2. Installs `git`, `curl`, `unzip`, `rust`, `clang` via `pkg`.
3. Downloads `bun-linux-aarch64-android.zip` to `$PREFIX/bin/bun`.
4. Clones the fork to `~/.local/share/oh-my-pi` (shallow, branch
   `android-direct`).
5. Runs `scripts/build-termux.sh` to compile `pi_natives` for the device
   (**30-60 min** on a typical phone).
6. Drops an `omp` wrapper at `$PREFIX/bin/omp`.
7. Copies `templates/AGENTS.md` to `~/.omp/agent/AGENTS.md`.

## Verify

```bash
omp --version        # prints the version string
omp -p "echo hello"  # prints "hello" and exits 0
omp                  # launches the TUI
```

## Build the native addon manually

The installer runs `scripts/build-termux.sh` once. To rebuild later (e.g.
after a fork update that bumped the addon):

```bash
cd ~/.local/share/oh-my-pi
git pull --ff-only origin android-direct
bash scripts/build-termux.sh
```

The build is **single-job-by-default with 2-job cap** to avoid OOMing
on 4-6 GB phones. Override with `CARGO_BUILD_JOBS=4` if you have more
RAM.

## Update

```bash
curl -fsSL https://raw.githubusercontent.com/Pondbreexpiate83/oh-my-pi/android-direct/scripts/install-termux.sh | sh
```

The installer is idempotent: it `git fetch && git reset --hard`s the
fork to the latest `android-direct`, then re-runs the build. Bun and
Termux packages are not re-installed if already present.

## Uninstall

```bash
rm -rf ~/.local/share/oh-my-pi
rm -f $PREFIX/bin/omp
rm -rf ~/.omp
```

Termux packages (`git`, `curl`, `rust`, `clang`, `bun`) and Termux:API
are not removed — they may be in use by other tools.

## Known limits

- **Build time:** 30-60 min on a typical phone. Cannot be reduced
  without a prebuilt binary (which is out of scope for this fork —
  upstream does not publish Android builds).
- **Memory:** phones have 4-8 GB total. Long subprocess pipelines
  may OOM; spawn fewer concurrent agents if you hit this.
- **Clipboard:** text is bridged via `termux-clipboard-set` /
  `termux-clipboard-get`. Image clipboard is unavailable.
- **Browser tool:** Puppeteer/Chromium is heavy on Android; gated off
  by default upstream.
- **`bun run` cwd bug:** under `/data/data` with unreadable ancestors,
  Bun may fail with `CouldntReadCurrentDirectory`. Workaround: cd to
  a path with readable ancestors first.
- **Process tools:** `Process::from_pid` returns `None` on hosts that
  lack `pidfd_open` (Android < 14). The addon still loads, but
  process-tree operations silently no-op.

## Source

- Fork: https://github.com/Pondbreexpiate83/oh-my-pi (branch `android-direct`)
- Upstream: https://github.com/can1357/oh-my-pi
- Plan: `docs/superpowers/plans/2026-06-22-omp-termux-native.md`
- Spec: `docs/superpowers/specs/2026-06-22-omp-termux-native-design.md`

## Reporting issues

- **Fork-specific (Android build, install, Termux behavior):**
  https://github.com/Pondbreexpiate83/oh-my-pi/issues
- **General omp behavior:** upstream
  https://github.com/can1357/oh-my-pi/issues

## Syncing with upstream

The fork is rebased on top of `can1357/oh-my-pi` main. To pull new
upstream commits:

```bash
cd ~/.local/share/oh-my-pi
git fetch upstream main
git rebase upstream/main
# If conflicts, resolve in the 5 modified files:
#   crates/pi-natives/Cargo.toml
#   crates/pi-natives/src/lib.rs
#   crates/pi-natives/src/crash_handler.rs
#   crates/pi-natives/src/clipboard.rs
#   crates/pi-shell/src/process.rs
#   packages/natives/native/loader-state.js
# Then rebuild to verify:
bash scripts/build-termux.sh
```

See `docs/port-changes.md` for the rationale of each modification.
