#!/usr/bin/env bash
# Termux end-user installer for oh-my-pi (omp) — native bionic build.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Pondbreexpiate83/oh-my-pi/android-direct/scripts/install-termux.sh | sh
#
# This script:
#   1. Verifies the environment (Termux, aarch64, Android 14+).
#   2. Installs the required Termux packages: git, curl, unzip, rust, clang.
#   3. Installs Bun (android-aarch64 build) if not already on PATH.
#   4. Clones the Pondbreexpiate83/oh-my-pi fork at the android-direct branch
#      into ~/.local/share/oh-my-pi.
#   5. Runs scripts/build-termux.sh to compile pi_natives for the device
#      (~30-60 min on a typical phone).
#   6. Drops an `omp` wrapper at $PREFIX/bin/omp.
#   7. Installs templates/AGENTS.md to ~/.omp/agent/AGENTS.md.
#
# To upgrade later, re-run this script.
set -euo pipefail

# ---- 1. Pre-flight checks ---------------------------------------------
case "$(uname -m)" in
	aarch64) ;;
	*) echo "ERROR: this installer targets aarch64 Termux only (got: $(uname -m))." >&2; exit 1;;
esac
case "${TERMUX_VERSION:-}${PREFIX:-}" in
	*com.termux*) ;;
	*) echo "ERROR: this installer must run inside Termux." >&2; exit 1;;
esac
ANDROID_VERSION="$(getprop ro.build.version.release 2>/dev/null || echo 0)"
case "${ANDROID_VERSION}" in
	14|15|16|17) ;;
	*) echo "ERROR: Android 14+ required (you have ${ANDROID_VERSION})." >&2
	   echo "       The pi-natives addon uses pidfd_open/pidfd_send_signal," >&2
	   echo "       which need kernel 5.15+ (Android 14+)." >&2
	   exit 1;;
esac

# ---- 2. Pkg prerequisites ---------------------------------------------
for pkg in git curl unzip rust clang; do
	if ! command -v "${pkg%%/*}" >/dev/null 2>&1; then
		pkg install -y "${pkg}"
	fi
done
# Confirm the install actually worked.
for cmd in git curl unzip rustc clang cargo; do
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		echo "ERROR: ${cmd} not installed and pkg install did not provide it." >&2
		exit 1
	fi
done

# ---- 3. Bun (android build) ------------------------------------------
if ! command -v bun >/dev/null 2>&1; then
	echo ">>> Installing Bun (android aarch64) ..."
	curl -fsSL -o "${PREFIX}/tmp/bun.zip" \
		https://github.com/oven-sh/bun/releases/latest/download/bun-linux-aarch64-android.zip
	unzip -j -o "${PREFIX}/tmp/bun.zip" '*/bun' -d "${PREFIX}/bin"
	chmod +x "${PREFIX}/bin/bun"
	rm -f "${PREFIX}/tmp/bun.zip"
fi

# ---- 4. Fork source --------------------------------------------------
INSTALL_ROOT="${HOME}/.local/share/oh-my-pi"
if [ ! -d "${INSTALL_ROOT}" ]; then
	echo ">>> Cloning fork into ${INSTALL_ROOT} ..."
	git clone --depth 1 --branch android-direct \
		https://github.com/Pondbreexpiate83/oh-my-pi.git "${INSTALL_ROOT}"
fi
(
	cd "${INSTALL_ROOT}"
	git fetch origin android-direct
	git reset --hard origin/android-direct
)

# ---- 5. Build pi_natives ---------------------------------------------
echo ">>> Building pi_natives (this takes 30-60 min on a phone) ..."
(
	cd "${INSTALL_ROOT}"
	bash scripts/build-termux.sh
)

# ---- 6. AGENTS.md ----------------------------------------------------
mkdir -p "${HOME}/.omp/agent"
cp "${INSTALL_ROOT}/templates/AGENTS.md" "${HOME}/.omp/agent/AGENTS.md"

# ---- 7. Wrapper ------------------------------------------------------
cat >"${PREFIX}/bin/omp" <<EOF
#!/usr/bin/env bash
exec bun "${INSTALL_ROOT}/packages/coding-agent/src/cli.ts" "\$@"
EOF
chmod +x "${PREFIX}/bin/omp"

cat <<'MSG'

omp is installed.

Try:
  omp --version
  omp -p "echo hello"
  omp

See https://github.com/Pondbreexpiate83/oh-my-pi/blob/android-direct/docs/termux-port.md
for usage and known limits.

To upgrade later, re-run this installer:
  curl -fsSL https://raw.githubusercontent.com/Pondbreexpiate83/oh-my-pi/android-direct/scripts/install-termux.sh | sh
MSG
