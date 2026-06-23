#!/usr/bin/env bash
# Cross-compile pi_natives for aarch64-linux-android (Termux target).
# Works on:
#   1. Linux host with NDK r27 + cargo + rustup target aarch64-linux-android
#   2. GitHub Actions runner (ubuntu-24.04) — see .github/workflows/build-android.yml
#
# Produces:
#   packages/natives/native/pi_natives.android-arm64.node
#   packages/natives/native/pi_natives.android-arm64.node.sha256
#
# Required env vars (auto-detected for CI, override for local):
#   ANDROID_NDK_ROOT   path to NDK root (e.g. /opt/android-ndk-r27d)
#   CARGO_HOME         cargo home (defaults to ~/.cargo)
#   RUSTUP_HOME        rustup home (defaults to ~/.rustup; not used if no rustup)
set -euo pipefail

: "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT must be set (e.g. /opt/android-ndk-r27d)}"
: "${CARGO_HOME:=${HOME}/.cargo}"

# Resolve repository root from this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Cross-compile toolchain. NDK r27 ships its own clang in:
#   toolchains/llvm/prebuilt/<host>/bin/clang
NDK_CLANG="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
NDK_CLANGXX="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
if [ ! -x "${NDK_CLANG}" ]; then
	echo "ERROR: NDK clang not found at ${NDK_CLANG}" >&2
	echo "       Set ANDROID_NDK_ROOT correctly (current: ${ANDROID_NDK_ROOT})" >&2
	exit 1
fi

export CC_aarch64_linux_android="${NDK_CLANG}"
export CXX_aarch64_linux_android="${NDK_CLANGXX}"
export AR_aarch64_linux_android="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-ar"
# tree-sitter-just's scanner.c breaks with -DNDEBUG under -O3; force assertions.
export CFLAGS_aarch64_linux_android="-UNDEBUG"
# Use a page size compatible with the largest Android devices.
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"

# Add the Android target to the active rustup toolchain. Required because
# rustup-managed targets are not auto-installed; we need rust-std for
# aarch64-linux-android to cross-compile.
if command -v rustup >/dev/null 2>&1; then
	ACTIVE_TOOLCHAIN="$(rustup show active-toolchain 2>/dev/null | awk '{print $1}')"
	if [ -n "${ACTIVE_TOOLCHAIN}" ]; then
		rustup target add aarch64-linux-android --toolchain "${ACTIVE_TOOLCHAIN}" || true
	fi
else
	echo "WARN: rustup not found; assuming the target is already installed." >&2
fi

# Build. Use --profile local (lto=thin, codegen-units=16) to fit in CI runner
# RAM; full release (lto=fat) will OOM on smaller hosts.
cargo build \
	--target aarch64-linux-android \
	--profile local \
	-p pi-natives

# Stage the artifact at the loader's expected path.
mkdir -p packages/natives/native
ARTIFACT="target/aarch64-linux-android/local/libpi_natives.so"
if [ ! -f "${ARTIFACT}" ]; then
	echo "ERROR: build did not produce ${ARTIFACT}" >&2
	exit 1
fi
cp "${ARTIFACT}" packages/natives/native/pi_natives.android-arm64.node

# Compute and write the sha256 next to the .node file.
sha256sum packages/natives/native/pi_natives.android-arm64.node \
	> packages/natives/native/pi_natives.android-arm64.node.sha256

echo
echo "Built: packages/natives/native/pi_natives.android-arm64.node"
cat packages/natives/native/pi_natives.android-arm64.node.sha256
