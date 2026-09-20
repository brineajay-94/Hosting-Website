#!/usr/bin/env bash
# ============================================================
#  BrineStudios — one-line installer bootstrap
#  BrineStudios · CEO: brineajay
#
#  Usage (run as root on Ubuntu/Debian):
#      bash <(curl -s https://YOUR-URL)
#   or
#      curl -fsSL https://YOUR-URL | sudo bash
# ============================================================

set -u

REPO="${BT_REPO:-https://github.com/brineajay-94/Hosting-Website.git}"
BRANCH="${BT_BRANCH:-main}"
DIR="${BT_DIR:-/opt/brinestudios}"

ORANGE=$'\033[38;5;208m'; GREEN=$'\033[32m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
info() { printf '%s\n' "${ORANGE}${1}${RESET}"; }
ok()   { printf '%s\n' "${GREEN}✓ ${1}${RESET}"; }
err()  { printf '%s\n' "${RED}✗ ${1}${RESET}" >&2; }

printf '%s\n' "${ORANGE}"
cat <<'ASCII'
   ____       _
  | __ ) _ __(_)_ __   ___
  |  _ \| '__| | '_ \ / _ \
  | |_) | |  | | | | |  __/
  |____/|_|  |_|_| |_|\___|
        B R I N E S T U D I O S
ASCII
printf '%s\n' "${RESET}"

if [ "$(id -u)" -ne 0 ]; then
  err "Please run as root (prefix with sudo)."
  exit 1
fi

# ---- Fetch the project -----------------------------------------------------
fetch_with_git() {
  if [ -d "$DIR/.git" ]; then
    info "Updating existing install in $DIR ..."
    git -C "$DIR" fetch --depth 1 origin "$BRANCH" >/dev/null 2>&1 && \
      git -C "$DIR" reset --hard "origin/$BRANCH" >/dev/null 2>&1
  else
    info "Downloading BrineStudios to $DIR ..."
    rm -rf "$DIR"
    git clone --depth 1 --branch "$BRANCH" "$REPO" "$DIR"
  fi
}

fetch_with_tar() {
  local tmp url
  tmp="$(mktemp -d)"
  url="https://codeload.github.com/brineajay-94/Hosting-Website/tar.gz/refs/heads/$BRANCH"
  info "Downloading BrineStudios archive ..."
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp/src.tgz" || { err "download failed"; exit 1; }
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp/src.tgz" "$url" || { err "download failed"; exit 1; }
  else
    err "Need git, curl or wget installed."; exit 1
  fi
  tar -xzf "$tmp/src.tgz" -C "$tmp" || { err "extract failed"; exit 1; }
  rm -rf "$DIR"; mkdir -p "$DIR"
  cp -a "$tmp/Hosting-Website-$BRANCH/." "$DIR/"
  rm -rf "$tmp"
}

if command -v git >/dev/null 2>&1; then
  fetch_with_git
else
  fetch_with_tar
fi

if [ ! -f "$DIR/brinestudios.sh" ]; then
  err "Install failed — brinestudios.sh not found in $DIR"
  exit 1
fi
ok "BrineStudios installed in $DIR"

# ---- Open the menu ---------------------------------------------------------
exec bash "$DIR/brinestudios.sh" "$@"
