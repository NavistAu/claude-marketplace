#!/bin/bash
set -euo pipefail

# install-gh-release.sh — download a binary from GitHub Releases
#
# Usage:
#   curl -fsSL <url-to-this-script> | bash -s -- \
#     --repo owner/repo --binary name --version 1.0.0 --dest /path/to/bin
#
# Detects OS and architecture, downloads the matching release asset,
# extracts and installs it. No dependencies beyond curl, tar, uname.

REPO=""
BINARY=""
VERSION=""
DEST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="$2"; shift 2 ;;
    --binary)  BINARY="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --dest)    DEST="$2"; shift 2 ;;
    *) echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

for var in REPO BINARY VERSION DEST; do
  if [[ -z "${!var}" ]]; then
    echo "error: --$(echo $var | tr '[:upper:]' '[:lower:]') is required" >&2
    exit 1
  fi
done

# Detect platform
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
  darwin) OS_TARGET="apple-darwin" ;;
  linux)  OS_TARGET="unknown-linux-gnu" ;;
  *)
    echo "error: unsupported OS: $OS" >&2
    exit 1
    ;;
esac

case "$ARCH" in
  arm64|aarch64) ARCH_TARGET="aarch64" ;;
  x86_64)        ARCH_TARGET="x86_64" ;;
  *)
    echo "error: unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

TARGET="${ARCH_TARGET}-${OS_TARGET}"
ASSET_NAME="${BINARY}-${TARGET}.tar.gz"
URL="https://github.com/${REPO}/releases/download/v${VERSION}/${ASSET_NAME}"

echo "Installing ${BINARY} v${VERSION} for ${TARGET}..."

mkdir -p "$DEST"
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

HTTP_CODE=$(curl -fsSL -w "%{http_code}" -o "$TMPFILE" "$URL" 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "error: download failed (HTTP $HTTP_CODE)" >&2
  echo "  URL: $URL" >&2
  echo "  Check that release v${VERSION} exists with asset ${ASSET_NAME}" >&2
  exit 1
fi

tar xzf "$TMPFILE" -C "$DEST"
chmod +x "$DEST/$BINARY"

if "$DEST/$BINARY" --version >/dev/null 2>&1; then
  echo "Installed ${BINARY} v${VERSION} → ${DEST}/${BINARY}"
else
  echo "Installed ${BINARY} → ${DEST}/${BINARY} (no --version support)"
fi
