#!/usr/bin/env bash
# MemPalace installer — fetches prebuilt native binary + embedding model.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/MemPalace/mempalace/main/install.sh | bash
#
# Env overrides:
#   MEMPALACE_VERSION   Release tag to install (default: latest)
#   MEMPALACE_INSTALL   Install prefix (default: $HOME/.mempalace)
#   MEMPALACE_REPO      GitHub repo (default: MemPalace/mempalace)
#   MEMPALACE_NO_MODEL  Skip GGUF embedding model download (default: 0)

set -euo pipefail

REPO="${MEMPALACE_REPO:-MemPalace/mempalace}"
VERSION="${MEMPALACE_VERSION:-latest}"
INSTALL_DIR="${MEMPALACE_INSTALL:-$HOME/.mempalace}"
BIN_DIR="$INSTALL_DIR/bin"
LIB_DIR="$INSTALL_DIR/lib"
MODEL_URL="https://huggingface.co/nomic-ai/nomic-embed-text-v1.5-GGUF/resolve/main/nomic-embed-text-v1.5.f16.gguf"

C_RESET='\033[0m'; C_BOLD='\033[1m'; C_DIM='\033[2m'
C_BLUE='\033[34m'; C_GREEN='\033[32m'; C_RED='\033[31m'; C_YELLOW='\033[33m'

info()  { printf "%b==>%b %s\n" "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
warn()  { printf "%bwarn:%b %s\n" "$C_YELLOW$C_BOLD" "$C_RESET" "$*" >&2; }
ok()    { printf "%b✓%b %s\n" "$C_GREEN$C_BOLD" "$C_RESET" "$*"; }
die()   { printf "%berror:%b %s\n" "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"; }

detect_platform() {
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)

  case "$os" in
    darwin) os="darwin" ;;
    linux)  os="linux" ;;
    *)      die "unsupported OS: $os" ;;
  esac

  case "$arch" in
    x86_64|amd64) arch="x86_64" ;;
    arm64|aarch64) arch="aarch64" ;;
    *) die "unsupported arch: $arch" ;;
  esac

  printf "%s-%s" "$os" "$arch"
}

resolve_version() {
  if [ "$VERSION" = "latest" ]; then
    need curl
    VERSION=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
      | grep -oE '"tag_name":[[:space:]]*"[^"]+"' \
      | head -n1 \
      | sed -E 's/.*"([^"]+)"$/\1/')
    [ -n "$VERSION" ] || die "could not resolve latest release tag from $REPO"
  fi
}

download() {
  local url="$1" out="$2"
  info "fetching $url"
  curl -fL --progress-bar -o "$out" "$url" || die "download failed: $url"
}

install_binary() {
  local platform="$1"
  local tarball="mempalace-${platform}.tar.gz"
  local url="https://github.com/$REPO/releases/download/$VERSION/$tarball"
  local tmp
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  mkdir -p "$BIN_DIR"
  download "$url" "$tmp/$tarball"
  tar -xzf "$tmp/$tarball" -C "$tmp"
  [ -f "$tmp/mempalace" ] || die "tarball missing 'mempalace' binary"
  install -m 755 "$tmp/mempalace" "$BIN_DIR/mempalace"
  ok "installed $BIN_DIR/mempalace"
}

install_model() {
  if [ "${MEMPALACE_NO_MODEL:-0}" = "1" ]; then
    warn "skipping embedding model download (MEMPALACE_NO_MODEL=1)"
    return
  fi
  mkdir -p "$LIB_DIR"
  if [ -f "$LIB_DIR/minilm.gguf" ]; then
    ok "embedding model already present at $LIB_DIR/minilm.gguf"
    return
  fi
  download "$MODEL_URL" "$LIB_DIR/minilm.gguf"
  ok "embedding model saved to $LIB_DIR/minilm.gguf"
}

shell_hint() {
  local shell_rc shell_name
  shell_name=$(basename "${SHELL:-/bin/bash}")
  case "$shell_name" in
    zsh)  shell_rc="$HOME/.zshrc" ;;
    bash) shell_rc="$HOME/.bashrc" ;;
    fish) shell_rc="$HOME/.config/fish/config.fish" ;;
    *)    shell_rc="your shell rc file" ;;
  esac

  echo
  printf "%bMemPalace installed to%b %s\n" "$C_BOLD" "$C_RESET" "$INSTALL_DIR"
  echo
  printf "%bNext step:%b add to PATH\n\n" "$C_BOLD" "$C_RESET"
  if [ "$shell_name" = "fish" ]; then
    printf "  fish_add_path %s\n\n" "$BIN_DIR"
  else
    printf "  echo 'export PATH=\"%s:\$PATH\"' >> %s\n" "$BIN_DIR" "$shell_rc"
    printf "  source %s\n\n" "$shell_rc"
  fi
  printf "%bQuick check:%b\n\n  mempalace stats\n\n" "$C_BOLD" "$C_RESET"
  printf "%bDocs:%b https://github.com/%s\n" "$C_DIM" "$C_RESET" "$REPO"
}

main() {
  need curl
  need tar
  need uname
  need grep

  info "detecting platform"
  local platform
  platform=$(detect_platform)
  ok "platform: $platform"

  info "resolving version"
  resolve_version
  ok "version: $VERSION"

  install_binary "$platform"
  install_model
  shell_hint
}

main "$@"
