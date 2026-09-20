#!/usr/bin/env bash
# ============================================================
#  BrineTeam Installer — terminal UI helpers
# ============================================================

# ---- Colours (disabled when not a TTY) -------------------------------------
if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'; C_ORANGE=$'\033[38;5;208m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""
  C_BLUE=""; C_CYAN=""; C_ORANGE=""
fi

bt_hr() { printf '%s\n' "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"; }

bt_info() { printf '%s\n' "${C_CYAN}[i]${C_RESET} $*"; }
bt_ok()   { printf '%s\n' "${C_GREEN}[✓]${C_RESET} $*"; }
bt_warn() { printf '%s\n' "${C_YELLOW}[!]${C_RESET} $*"; }
bt_err()  { printf '%s\n' "${C_RED}[✗]${C_RESET} $*" >&2; }
bt_step() { printf '\n%s\n' "${C_BOLD}${C_ORANGE}▶ $*${C_RESET}"; }

bt_ensure_state_dir() {
  [ -d "$BT_STATE_DIR" ] || mkdir -p "$BT_STATE_DIR" 2>/dev/null || true
  [ -f "$BT_LOG_FILE" ] || : >"$BT_LOG_FILE" 2>/dev/null || true
}

bt_log() {
  bt_ensure_state_dir
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$BT_LOG_FILE" 2>/dev/null
}

# ---- Banner ----------------------------------------------------------------
bt_banner() {
  clear 2>/dev/null || true
  printf '%s' "${C_ORANGE}${C_BOLD}"
  cat <<'ASCII'
   ____       _         _____
  | __ ) _ __(_)_ __   |_   _|__  __ _ _ __ ___
  |  _ \| '__| | '_ \    | |/ _ \/ _` | '_ ` _ \
  | |_) | |  | | | | |   | |  __/ (_| | | | | | |
  |____/|_|  |_|_| |_|   |_|\___|\__,_|_| |_| |_|
ASCII
  printf '%s' "${C_RESET}"
  printf '%s\n' "${C_BOLD}         Hosting control installer${C_RESET}"
  bt_hr
  printf '  %s   %s\n' "${C_DIM}Company:${C_RESET}" "${C_BOLD}$BT_COMPANY${C_RESET}"
  printf '  %s       %s\n' "${C_DIM}CEO:${C_RESET}" "$BT_CEO"
  printf '  %s   %s  %s\n' "${C_DIM}Version:${C_RESET}" "$BT_VERSION" "${C_DIM}·  $BT_REPO${C_RESET}"
  bt_hr
}

# ---- Root check ------------------------------------------------------------
bt_require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    bt_err "This installer must run as root (it installs packages and edits Nginx)."
    printf '    Try:  %ssudo bash %s%s\n' "${C_BOLD}" "${BT_ROOT}/brineteam.sh" "${C_RESET}"
    exit 1
  fi
}

# ---- Input helpers ---------------------------------------------------------
bt_read() { # $1 prompt, $2 default -> echoes answer
  local prompt="$1" default="${2-}" answer
  if [ -n "$default" ]; then
    read -r -p "$(printf '%s' "${C_BOLD}$prompt${C_RESET} [$default]: ")" answer </dev/tty
    printf '%s' "${answer:-$default}"
  else
    read -r -p "$(printf '%s' "${C_BOLD}$prompt${C_RESET}: ")" answer </dev/tty
    printf '%s' "$answer"
  fi
}

bt_read_secret() { # $1 prompt -> echoes answer (no echo)
  local prompt="$1" answer
  read -r -s -p "$(printf '%s' "${C_BOLD}$prompt${C_RESET}: ")" answer </dev/tty
  printf '\n' >&2
  printf '%s' "$answer"
}

bt_confirm() { # $1 prompt, default no
  local answer
  read -r -p "$(printf '%s' "${C_BOLD}$1${C_RESET} [y/N]: ")" answer </dev/tty
  case "$answer" in y|Y|yes|YES) return 0;; *) return 1;; esac
}

bt_pause() {
  printf '\n%s' "${C_DIM}Press Enter to return to the menu...${C_RESET}"
  read -r _ </dev/tty || true
}

# ---- Status row ------------------------------------------------------------
bt_status() { # $1 = 0 ok / else fail, $2 label, $3 extra
  if [ "$1" -eq 0 ]; then
    printf '  %s  %-34s %s\n' "${C_GREEN}installed${C_RESET}" "$2" "${C_DIM}${3-}${C_RESET}"
  else
    printf '  %s  %-34s %s\n' "${C_RED}missing  ${C_RESET}" "$2" "${C_DIM}${3-}${C_RESET}"
  fi
}

# ---- Numbered menu ---------------------------------------------------------
# Usage: bt_menu "Title" "1:label" "2:label" ...
# Result in BT_CHOICE (the number key)
bt_menu() {
  local title="$1"; shift
  printf '\n%s\n' "${C_BOLD}$title${C_RESET}"
  bt_hr
  local item key label
  for item in "$@"; do
    key="${item%%:*}"; label="${item#*:}"
    printf '  %s%s)%s %s\n' "${C_BOLD}${C_ORANGE}" "$key" "${C_RESET}" "$label"
  done
  bt_hr
  local choice
  read -r -p "$(printf '%s' "${C_BOLD}Choose an option: ${C_RESET}")" choice </dev/tty
  BT_CHOICE="$choice"
}
