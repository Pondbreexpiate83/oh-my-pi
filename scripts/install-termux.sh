#!/usr/bin/env bash
# Termux end-user installer for omp (native bionic build).
# See docs/termux-port.md for the user-facing doc.
set -euo pipefail

# ---- 1. Pre-flight checks ------------------------------------------------
case "$(uname -m)" in
  aarch64) ;;
  *) echo "ERROR: this installer targets aarch64 Termux only (got: $(uname -m))." >&2; exit 1;;
esac
case "${TERMUX_VERSION:-}${PREFIX:-}" in
  *com.termux*) ;;
  *) echo "ERROR: this installer must run inside Termux." >&2; exit 1;;
esac

# ---- 2. Pkg prerequisites -----------------------------------------------
for pkg in git curl unzip; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    pkg install -y "$pkg"
  fi
done

# ---- 3. Bun (android build) ---------------------------------------------
if ! command -v bun >/dev/null 2>&1; then
  curl -fsSL -o /tmp/bun.zip \
    https://github.com/oven-sh/bun/releases/latest/download/bun-linux-aarch64-android.zip
  unzip -j -o /tmp/bun.zip '*/bun' -d "$PREFIX/bin"
  chmod +x "$PREFIX/bin/bun"
  rm -f /tmp/bun.zip
fi

# ---- 4. Fork source ------------------------------------------------------
INSTALL_ROOT="$HOME/.local/share/oh-my-pi"
if [ ! -d "$INSTALL_ROOT" ]; then
  git clone --depth 1 https://github.com/Pondbreexpiate83/oh-my-pi.git "$INSTALL_ROOT"
fi
( cd "$INSTALL_ROOT" && git pull --ff-only )

# ---- 5. Prebuilt .node ---------------------------------------------------
NATIVE_DIR="$INSTALL_ROOT/packages/natives/native"
mkdir -p "$NATIVE_DIR"
LATEST_JSON=$(curl -fsSL https://api.github.com/repos/Pondbreexpiate83/oh-my-pi/releases/latest)
NODE_URL=$(printf '%s' "$LATEST_JSON" \
  | grep '"browser_download_url":' \
  | grep 'pi_natives.android-arm64.node"' \
  | head -1 \
  | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$NODE_URL" ]; then
  echo "ERROR: no prebuilt pi_natives.android-arm64.node in latest release." >&2
  echo "       This may be a fork without published releases yet." >&2
  exit 1
fi
curl -fsSL "$NODE_URL" -o "$NATIVE_DIR/pi_natives.android-arm64.node"
chmod +x "$NATIVE_DIR/pi_natives.android-arm64.node"

# ---- 6. Apply patch 03 (loader add android-arm64) -----------------------
git -C "$INSTALL_ROOT" apply --check patches/03-loader-add-android-arm64.patch \
  || { echo "ERROR: patch 03 no longer applies; fork has drifted." >&2; exit 1; }
git -C "$INSTALL_ROOT" apply patches/03-loader-add-android-arm64.patch
# Revert after the install so the next `git pull` doesn't conflict.
# (Patch is needed at runtime only; the source tree must stay clean.)

# ---- 7. AGENTS.md -------------------------------------------------------
mkdir -p "$HOME/.omp/agent"
cp "$INSTALL_ROOT/templates/AGENTS.md" "$HOME/.omp/agent/AGENTS.md"

# ---- 8. Wrapper ---------------------------------------------------------
cat >"$PREFIX/bin/omp" <<'EOF'
#!/usr/bin/env bash
exec bun "$HOME/.local/share/oh-my-pi/packages/coding-agent/src/cli.ts" "$@"
EOF
chmod +x "$PREFIX/bin/omp"

# ---- 9. Revert patch 03 so the next `git pull` is clean ---------------
git -C "$INSTALL_ROOT" apply -R patches/03-loader-add-android-arm64.patch || true

cat <<'MSG'

omp is installed.

Try:
  omp --version
  omp -p "echo hello"
  omp

See https://github.com/Pondbreexpiate83/oh-my-pi/blob/android-port/docs/termux-port.md
for usage and known limits.
MSG
