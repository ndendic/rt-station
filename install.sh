#!/bin/sh
# Install or upgrade RT Station (the `rt` binary) on Linux x86_64.
#
#   curl -fsSL https://raw.githubusercontent.com/ndendic/rt-station/main/install.sh | sh
#
# Settings (all optional, read from the environment):
#   RT_VERSION      install this release (for example 0.4.0) instead of the latest
#   RT_INSTALL_DIR  folder to install into; default: $HOME/.local/bin
#   RT_FORCE=1      replace the target even when it is a symlink
#   RT_BASE_URL     where releases are downloaded from; default:
#                   https://github.com/ndendic/rt-station/releases
#
# Running it again is the upgrade. It never uses sudo.

set -eu

REPO_RELEASES="https://github.com/ndendic/rt-station/releases"
ARCHIVE="rt_linux_amd64.tar.gz"
SUMS="checksums.txt"

say() { printf '%s\n' "$*"; }
fail() { printf 'rt install: error: %s\n' "$*" >&2; exit 1; }

# --- Platform -------------------------------------------------------------

os=$(uname -s 2>/dev/null || echo unknown)
arch=$(uname -m 2>/dev/null || echo unknown)
case "$os" in
  Linux) ;;
  *) fail "this installer supports Linux x86_64 only (found: $os $arch). On Windows x64 use install.ps1. Other platforms are not supported yet." ;;
esac
case "$arch" in
  x86_64 | amd64) ;;
  *) fail "this installer supports Linux x86_64 only (found: $os $arch). Other architectures are not supported yet." ;;
esac

# --- Tools ----------------------------------------------------------------

if command -v curl >/dev/null 2>&1; then
  download() { curl -fsSL --retry 3 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  download() { wget -q -O "$2" "$1"; }
else
  fail "curl or wget is required to download rt"
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  fail "sha256sum or shasum is required to verify the download"
fi

for tool in tar mktemp awk; do
  command -v "$tool" >/dev/null 2>&1 || fail "$tool is required"
done

# --- Where from, where to -------------------------------------------------

base=${RT_BASE_URL:-$REPO_RELEASES}
base=${base%/}
if [ -n "${RT_VERSION:-}" ]; then
  version="v${RT_VERSION#v}"
  url="$base/download/$version"
  label="$version"
else
  url="$base/latest/download"
  label="latest"
fi

if [ -n "${RT_INSTALL_DIR:-}" ]; then
  dir=$RT_INSTALL_DIR
else
  [ -n "${HOME:-}" ] || fail "HOME is not set; set RT_INSTALL_DIR to choose a folder"
  dir="$HOME/.local/bin"
fi
dir=${dir%/}
target="$dir/rt"

if [ -L "$target" ] && [ "${RT_FORCE:-}" != "1" ]; then
  fail "$target is a symlink (to $(readlink "$target" 2>/dev/null || echo '?')).
This usually means rt is linked to a build from source on this machine, and
installing would replace that link. Remove the link yourself, or run again
with RT_FORCE=1 to replace it with the released binary."
fi

# --- Temp space, removed on every exit ------------------------------------

tmp=""
staged=""
cleanup() {
  [ -n "$staged" ] && rm -f "$staged"
  [ -n "$tmp" ] && rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

tmp=$(mktemp -d "${TMPDIR:-/tmp}/rt-install.XXXXXX") || fail "could not create a temp folder"

# --- Download and verify --------------------------------------------------

say "Downloading rt ($label) from $url"
download "$url/$ARCHIVE" "$tmp/$ARCHIVE" || fail "download failed: $url/$ARCHIVE"
download "$url/$SUMS" "$tmp/$SUMS" || fail "download failed: $url/$SUMS"

expected=$(awk -v f="$ARCHIVE" '$2 == f || $2 == "*" f { print $1; exit }' "$tmp/$SUMS")
[ -n "$expected" ] || fail "$SUMS has no line for $ARCHIVE"
actual=$(sha256 "$tmp/$ARCHIVE")
if [ "$expected" != "$actual" ]; then
  fail "checksum mismatch for $ARCHIVE
  expected: $expected
  got:      $actual
Nothing was installed."
fi
say "Checksum OK ($actual)"

mkdir "$tmp/x"
tar -xzf "$tmp/$ARCHIVE" -C "$tmp/x" || fail "could not unpack $ARCHIVE"
[ -f "$tmp/x/rt" ] || fail "$ARCHIVE does not contain rt at its root"

# --- Install atomically ---------------------------------------------------
# Copy into the target folder first (same file system), then rename over the
# old file. A rename swaps the directory entry, so an rt that is running now
# keeps its old file and goes on working.

mkdir -p "$dir" || fail "could not create $dir"
staged="$dir/.rt.new.$$"
cp "$tmp/x/rt" "$staged" || fail "could not write to $dir"
chmod 755 "$staged"
mv -f "$staged" "$target" || fail "could not replace $target"
staged=""

installed=$("$target" --version 2>/dev/null || echo "rt (version unknown)")
say "Installed $installed to $target"

case ":${PATH:-}:" in
  *":$dir:"*)
    found=$(command -v rt 2>/dev/null || true)
    if [ -n "$found" ] && [ "$found" != "$target" ]; then
      say "Note: another rt comes first on your PATH: $found"
    fi
    ;;
  *)
    say ""
    say "$dir is not on your PATH. Add this line to your shell profile"
    say "(~/.profile, ~/.bashrc or ~/.zshrc), then open a new terminal:"
    say ""
    say "  export PATH=\"$dir:\$PATH\""
    ;;
esac
