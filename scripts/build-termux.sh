#!/usr/bin/env bash
# Build pi_natives for aarch64-linux-android directly on Termux.
# No NDK, no cargo-zigbuild, no cross-compile — uses the device's own
# rust + clang and the android aarch64 target that ships with the Termux
# rust package.
#
# Prerequisites (installed by scripts/install-termux.sh):
#   pkg install rust clang
#
# Produces:
#   packages/natives/native/pi_natives.android-arm64.node
#   packages/natives/native/pi_natives.android-arm64.node.sha256
set -euo pipefail

# Sanity: are we actually on Termux?
if [ -z "${TERMUX_VERSION:-}" ] && [ -z "${PREFIX:-}" ]; then
	echo "ERROR: this script must be run inside Termux." >&2
	exit 1
fi
case "$(uname -m)" in
	aarch64) ;;
	*) echo "ERROR: Termux aarch64 only (got $(uname -m))." >&2; exit 1;;
esac

# Sanity: is the target installed? Termux's `pkg install rust` provides
# aarch64-linux-android by default, but if it's missing, fail with a hint
# instead of a confusing cargo error.
RUST_SYSROOT="$(rustc --print sysroot)"
if [ ! -d "${RUST_SYSROOT}/lib/rustlib/aarch64-linux-android" ]; then
	echo "ERROR: rust target aarch64-linux-android not installed in ${RUST_SYSROOT}" >&2
	echo "       Run: \`rustup target add aarch64-linux-android\` (if rustup is present)" >&2
	echo "       or reinstall rust: \`pkg install rust\`" >&2
	exit 1
fi

# Sanity: is clang available? Termux's clang lives at $PREFIX/bin/clang.
if ! command -v clang >/dev/null 2>&1; then
	echo "ERROR: clang not found." >&2
	echo "       Run: \`pkg install clang\`" >&2
	exit 1
fi

# Resolve repository root from this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${REPO_ROOT}"

# Cross-compile env. On Termux we target the same triple (aarch64-linux-android)
# but the actual linker/cc is the system clang (no NDK needed for this crate).
export CC_aarch64_linux_android="${PREFIX}/bin/clang"
export CXX_aarch64_linux_android="${PREFIX}/bin/clang++"
export AR_aarch64_linux_android="${PREFIX}/bin/llvm-ar"
# tree-sitter-just: scanner.c breaks with -DNDEBUG under -O3.
export CFLAGS_aarch64_linux_android="-UNDEBUG"
# Android 14+ devices support 16 KiB pages; tell the linker so RELRO segments
# don't exceed the page size.
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-C link-arg=-Wl,-z,max-page-size=16384"

# Build. Use --profile local (lto=thin, codegen-units=16) to keep memory
# pressure reasonable on a phone. Full release (lto=fat) can OOM on 4 GB devices.
cargo build \
	--target aarch64-linux-android \
	--profile local \
	-p pi-natives

# Stage the artifact.
mkdir -p packages/natives/native
ARTIFACT="target/aarch64-linux-android/local/libpi_natives.so"
if [ ! -f "${ARTIFACT}" ]; then
	echo "ERROR: build did not produce ${ARTIFACT}" >&2
	exit 1
fi
cp "${ARTIFACT}" packages/natives/native/pi_natives.android-arm64.node

# sha256.
sha256sum packages/natives/native/pi_natives.android-arm64.node \
	> packages/natives/native/pi_natives.android-arm64.node.sha256

echo
echo "Built: packages/natives/native/pi_natives.android-arm64.node"
cat packages/natives/native/pi_natives.android-arm64.node.sha256
