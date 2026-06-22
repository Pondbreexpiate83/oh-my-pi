#!/usr/bin/env bash
# Build pi_natives.android-arm64.node on a Linux host with NDK r27 + cargo-zigbuild.
# See docs/superpowers/plans/2026-06-22-omp-termux-native.md for context.
set -euo pipefail

: "${ANDROID_NDK_ROOT:?ANDROID_NDK_ROOT must be set (e.g. /opt/android-ndk-r27)}"
: "${CARGO_HOME:?CARGO_HOME must be set}"

# Resolve repository root from this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# 1. Apply patches on top of the upstream commit.
git apply --check patches/[0-9][0-9]-*.patch
git apply patches/[0-9][0-9]-*.patch
trap 'git apply -R patches/[0-9][0-9]-*.patch || true' EXIT

# 2. Cross-compile pi_natives for aarch64-linux-android.
export CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
export CC_aarch64_linux_android="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
export CXX_aarch64_linux_android="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
# tree-sitter-just: scanner.c breaks with -DNDEBUG under -O3.
export CFLAGS_aarch64_linux_android="-UNDEBUG"
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"

cargo zigbuild \
  -p pi-natives \
  --target aarch64-linux-android \
  --profile local

# 3. Stage the .node file at the loader's expected path.
mkdir -p packages/natives/native
cp target/aarch64-linux-android/local/libpi_natives.so \
   packages/natives/native/pi_natives.android-arm64.node

# 4. Compute checksum.
sha256sum packages/natives/native/pi_natives.android-arm64.node \
  > packages/natives/native/pi_natives.android-arm64.node.sha256

# 5. Reverse patches so the working tree is clean.
git apply -R patches/[0-9][0-9]-*.patch
trap - EXIT

echo "Built packages/natives/native/pi_natives.android-arm64.node"
cat packages/natives/native/pi_natives.android-arm64.node.sha256
