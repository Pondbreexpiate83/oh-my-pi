# Port changes vs upstream

This document describes every modification in the
`Pondbreexpiate83/oh-my-pi` fork relative to the upstream
`can1357/oh-my-pi` repository. The fork is rebased on top of
upstream's `main` branch; the modifications below are the **only**
deltas that must be preserved on every rebase.

When upstream changes one of the files below, expect a merge conflict.
Resolve it by re-applying the equivalent change from this document on
top of upstream's new file content. The `scripts/build-termux.sh` (or
`scripts/build-android.sh` for Linux) is the regression test: if it
compiles, the rebase is correct.

## 1. `crates/pi-natives/src/lib.rs`

**Change:** removed `#![feature(alloc_error_hook)]` on the line that
follows the `#![allow(...)]` attributes.

**Why:** `pi_natives` is built for `aarch64-linux-android`, which uses
the bionic libc. The build script (`scripts/build-termux.sh`) does not
set up a nightly Rust toolchain. The `feature(alloc_error_hook)` is
nightly-only and fails to compile on stable.

**Conflict resolution:** upstream occasionally adds new `#![feature(...)]`
attributes between `#![allow(...)]` and the `pub mod` block. Re-apply
this single-line deletion in the same position.

## 2. `crates/pi-natives/src/crash_handler.rs`

**Change:** replaced the body of `std::alloc::set_alloc_error_hook(...)`
inside `install()` with a 3-line comment explaining that the alloc hook
is disabled on bionic. Also removed the `static ALLOC_HOOK_ACTIVE:
AtomicBool` declaration (no longer referenced) and the
`AtomicBool, Ordering` imports from the use-list.

**Why:** same as #1 — `set_alloc_error_hook` is nightly-only. The
alloc hook's purpose (printing a backtrace and persisting to disk on
OOM) is a nice-to-have; we trade it for a working build on stable
Rust.

**Conflict resolution:** upstream may add new functions to
`crash_handler.rs` that depend on the alloc-hook report path. If
upstream renames or repurposes `format_alloc_report` /
`write_alloc_failure_line`, leave them in place; they are referenced
from the test module. The `set_alloc_error_hook` call itself must
remain replaced with the comment.

## 3. `crates/pi-natives/Cargo.toml`

**Change:** removed the line `arboard.workspace = true` from
`[dependencies]`. Added a new target block at the bottom of
`[dependencies]`:

```toml
[target.'cfg(not(target_os = "android"))'.dependencies]
arboard.workspace = true
```

**Why:** `arboard` has no Android backend (it links X11/Wayland on
Linux, AppKit on macOS, Win32 on Windows). Linking it on Android
fails at the build script's `cc` step with unresolved FFI symbols.
The version-bumped `arboard` crate is also pulled in by the JS side
via `napi-rs` and is harmless when not linked into the Rust binary.

**Conflict resolution:** upstream may add new `[dependencies]` entries
or move the `arboard` line. Re-apply the move: ensure `arboard` is
NOT in the unconditional `[dependencies]` and IS in the
`[target.'cfg(not(target_os = "android"))'.dependencies]` block.

## 4. `crates/pi-natives/src/clipboard.rs`

This file has the most changes. Three categories:

### 4a. Android stubs

Added two `#[cfg(target_os = "android")]` functions BEFORE the
existing `copy_to_clipboard` function:

- `set_clipboard_text(_text: String) -> Result<()>` — returns
  `Err(Error::from_reason("clipboard bridged via termux-clipboard-set
  on Android"))`.
- `read_image_from_clipboard() -> task::Promise<Option<ClipboardImage>>` —
  returns `Ok(None)` always.

The `#[napi]` attribute is on the second one (the first is private).

### 4b. Existing arboard-using impls, gated to exclude Android

Three existing items are now `#[cfg(...)]` with `not(target_os = "android")`:

- The `use arboard::{Clipboard, Error as ClipboardError, ImageData}`
  import line.
- The `fn encode_png(image: ImageData<'_>) -> Result<Vec<u8>>` function.
- The `use std::io::Cursor;` and `use image::{DynamicImage, ImageFormat,
  RgbaImage};` imports (also unused on Android).

The `pub fn read_image_from_clipboard()` (the existing public function)
gets `#[cfg(not(target_os = "android"))]`.

### 4c. Existing cfg-gate tightening

- The existing `#[cfg(target_os = "linux")]` on the X11/Wayland
  `set_clipboard_text` is now `#[cfg(all(target_os = "linux",
  not(target_os = "android")))]`. On Android, BOTH `target_os =
  "linux"` and `target_os = "android"` are true (Android is Linux-
  kernel-based), so the original gate would compile arboard's
  X11 path on Android — which then fails to link.
- The existing `#[cfg(not(target_os = "linux"))]` on the macOS/Windows
  `set_clipboard_text` is now `#[cfg(all(not(target_os = "linux"),
  not(target_os = "android")))]` for the same reason.

**Why:** the Android triples in Rust set `target_os = "android"`, but
the Linux-kernel underneath also satisfies `target_os = "linux"` for
cargo's resolver. The original `cfg(target_os = "linux")` gate fires
on Android too, causing a duplicate definition of `set_clipboard_text`
when our Android stub (4a) is also compiled. The fix is to
explicitly exclude Android from the Linux and not(linux) branches.

**Conflict resolution:** if upstream changes the `cfg` predicates
(e.g., to add a new platform), apply the same `not(target_os =
"android")` filter. The Android stub functions (4a) must remain at
the top of the file (before `copy_to_clipboard`).

## 5. `crates/pi-shell/src/process.rs`

**Change:** the `#[cfg(target_os = "linux")] mod platform { ... }` is
now `#[cfg(any(target_os = "linux", target_os = "android"))]`.

**Why:** the platform-specific implementation (which uses
`pidfd_open`, `pidfd_send_signal`, `getpgid`, etc.) works fine on
Android 14+ (kernel 5.15+ exposes those syscalls through bionic).
The original Linux-only gate excluded Android, causing
`platform::Process` to be undefined and the `pi-shell` library to
fail to compile.

**Conflict resolution:** if upstream adds new platform branches or
splits the platform module, ensure the Android arm64 case is
included in whichever gate covers the pidfd implementation.

## 6. `packages/natives/native/loader-state.js`

**Change:** the `SUPPORTED_PLATFORMS` array now ends with
`"android-arm64"`. The line is:

```js
const SUPPORTED_PLATFORMS = ["linux-x64", "linux-arm64", "darwin-x64", "darwin-arm64", "win32-x64", "android-arm64"];
```

**Why:** the loader computes `platformTag = ${process.platform}-
${process.arch}` and rejects any `platformTag` not in
`SUPPORTED_PLATFORMS`. On Termux with `bun-linux-aarch64-android`,
this evaluates to `"android-arm64"`, which was not in the upstream
list, so the loader threw `Failed to load pi_natives native addon
for android-arm64` and refused to even try to load our prebuilt
.node.

**Conflict resolution:** if upstream adds a new platform, append it
to the end of the array. The Android entry is last (added by this
fork); keep it there to minimize diff churn on rebase.

## Non-changes (verified compatible)

These files were checked and **did not** need changes:

- `crates/pi-natives/src/appearance.rs` and `power.rs`: use
  `#[cfg(target_os = "macos")]` and `#[cfg(not(target_os =
  "macos"))]`. On Android, only the no-op fallback branch is
  compiled, which is a no-op `Ok(Self {})`. No link errors.
- `crates/pi-iso/src/lib.rs`: `BackendKind::native()` resolves to
  `Rcopy` on Android (anything not Linux, macOS, or Windows). The
  `Rcopy` backend is the universal fallback (git worktree or
  recursive copy) and works on any Unix.
- `crates/pi-natives/src/pty.rs`: uses `#[cfg(unix)]` /
  `#[cfg(windows)]`. On Android (Unix), `portable-pty` compiles
  against bionic's termios.
- `crates/brush-core-vendored/src/sys/unix/fs.rs` and `umask.rs`:
  already contain `#[cfg(target_os = "android")]` branches (upstream
  support for the Android port).
- `crates/brush-builtins-vendored/Cargo.toml`: the `procfs`
  dependency is gated under `cfg(any(target_os = "linux", target_os
  = "android"))`. Already correct.

## Build verification

After a rebase, run from a Linux host (preferred) or Termux:

```bash
# Linux host with NDK r27:
ANDROID_NDK_ROOT=/path/to/ndk-r27d bash scripts/build-android.sh

# Or on a Termux device:
bash scripts/build-termux.sh
```

A successful build produces
`packages/natives/native/pi_natives.android-arm64.node` plus
its `.sha256` sibling. If the build fails, the failure points to a
cfg-gate that the rebase missed.

The CI workflow at `.github/workflows/build-android.yml` is the
canonical regression test for any change to this fork.
