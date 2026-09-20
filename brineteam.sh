#!/usr/bin/env bash
# ============================================================
#  BrineTeam — Hosting control installer
#  BrineStudios  ·  CEO: brineajay
#
#  Run on the server:
#      sudo bash brineteam.sh
# ============================================================

set -u

# ---- Locate ourselves ------------------------------------------------------
BT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=installer/config.sh
. "$BT_ROOT/installer/config.sh"
# shellcheck source=installer/lib/ui.sh
. "$BT_ROOT/installer/lib/ui.sh"
# shellcheck source=installer/lib/deps.sh
. "$BT_ROOT/installer/lib/deps.sh"
# shellcheck source=installer/lib/site.sh
. "$BT_ROOT/installer/lib/site.sh"

bt_require_root

# ---- State line shown under the banner -------------------------------------
bt_state_line() {
  bt_deps_count
  local deps_txt site_txt
  if bt_deps_all_ok; then deps_txt="${C_GREEN}ready${C_RESET}"; else deps_txt="${C_YELLOW}$BT_DEPS_OK/$BT_DEPS_TOTAL installed${C_RESET}"; fi
  if bt_site_installed; then site_txt="${C_GREEN}installed ($BT_ST_DOMAIN)${C_RESET}"; else site_txt="${C_DIM}not installed${C_RESET}"; fi
  printf '  %s %b    %s %b\n' "${C_DIM}Dependencies:${C_RESET}" "$deps_txt" "${C_DIM}Website:${C_RESET}" "$site_txt"
}

# ---- Main loop -------------------------------------------------------------
main() {
  bt_load_state
  local running=1

  while [ "$running" -eq 1 ]; do
    bt_banner
    bt_state_line

    if bt_site_installed; then
      bt_menu "Main menu" \
        "1:Install / repair dependencies" \
        "2:Uninstall website" \
        "3:Update website" \
        "4:Reinstall website" \
        "5:Show status & statistics" \
        "6:Exit"
      case "$BT_CHOICE" in
        1) bt_install_deps; bt_pause ;;
        2) bt_uninstall_site; bt_load_state; bt_pause ;;
        3) bt_update_site; bt_pause ;;
        4) bt_reinstall_site; bt_load_state; bt_pause ;;
        5) bt_show_statistics; bt_pause ;;
        6|q|Q) running=0 ;;
        *) bt_warn "Invalid option."; sleep 1 ;;
      esac
    else
      bt_menu "Main menu" \
        "1:Install dependencies" \
        "2:Install website" \
        "3:Show status & statistics" \
        "4:Exit"
      case "$BT_CHOICE" in
        1) bt_install_deps; bt_pause ;;
        2)
          if bt_deps_all_ok; then
            bt_install_site
          else
            bt_warn "Dependencies are not installed yet. Please run option 1 first."
            bt_print_deps
          fi
          bt_pause ;;
        3) bt_show_statistics; bt_print_deps; bt_pause ;;
        4|q|Q) running=0 ;;
        *) bt_warn "Invalid option."; sleep 1 ;;
      esac
    fi
  done

  clear 2>/dev/null || true
  printf '%s\n' "${C_ORANGE}${C_BOLD}  Thanks for using BrineTeam — $BT_COMPANY${C_RESET}"
  printf '%s\n\n' "${C_DIM}  CEO: $BT_CEO  ·  $BT_REPO${C_RESET}"
}

main "$@"
