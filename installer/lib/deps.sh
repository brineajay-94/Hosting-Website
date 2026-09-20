#!/usr/bin/env bash
# ============================================================
#  BrineTeam Installer — dependency detection & installation
# ============================================================

# ---- Detect a single dependency -------------------------------------------
# $1 key, $2 check-command -> returns 0 if installed
bt_dep_ok() {
  local key="$1" check="$2"
  case "$key" in
    php)
      command -v php >/dev/null 2>&1 ;;
    php-fpm)
      command -v php-fpm >/dev/null 2>&1 || ls /usr/sbin/php-fpm* >/dev/null 2>&1 ;;
    mariadb)
      command -v mariadb >/dev/null 2>&1 || command -v mysql >/dev/null 2>&1 ;;
    localhost-ssl)
      [ -f "$BT_CERTS_DIR/privkey.pem" ] && [ -f "$BT_CERTS_DIR/fullchain.pem" ] ;;
    *)
      command -v "$check" >/dev/null 2>&1 ;;
  esac
}

# ---- PHP extension check ---------------------------------------------------
bt_php_ext_ok() {
  command -v php >/dev/null 2>&1 || return 1
  local ext missing=0
  for ext in $BT_PHP_EXT; do
    php -m 2>/dev/null | grep -qi "^${ext}$" || missing=1
  done
  return "$missing"
}

# ---- Count how many hard dependencies are satisfied ------------------------
# Sets BT_DEPS_OK and BT_DEPS_TOTAL
bt_deps_count() {
  BT_DEPS_TOTAL=0
  BT_DEPS_OK=0
  local row key check
  for row in "${BT_DEPS[@]}"; do
    IFS='|' read -r key _ check _ optional <<<"$row"
    [ "$optional" = "1" ] && continue
    BT_DEPS_TOTAL=$((BT_DEPS_TOTAL + 1))
    if bt_dep_ok "$key" "$check"; then BT_DEPS_OK=$((BT_DEPS_OK + 1)); fi
  done
  # PHP extensions count as one extra hard dependency
  BT_DEPS_TOTAL=$((BT_DEPS_TOTAL + 1))
  if bt_php_ext_ok; then BT_DEPS_OK=$((BT_DEPS_OK + 1)); fi
}

bt_deps_all_ok() {
  bt_deps_count
  [ "$BT_DEPS_OK" -eq "$BT_DEPS_TOTAL" ]
}

# ---- Print a full dependency status table ----------------------------------
bt_print_deps() {
  bt_deps_count
  printf '\n%s\n' "${C_BOLD}Dependencies${C_RESET}  ${C_DIM}($BT_DEPS_OK/$BT_DEPS_TOTAL required installed)${C_RESET}"
  bt_hr
  local row key apt check friendly optional svc
  for row in "${BT_DEPS[@]}"; do
    IFS='|' read -r key apt check friendly optional <<<"$row"
    local extra=""
    if bt_dep_ok "$key" "$check"; then
      svc="$(bt_service_state "$key")"
      [ -n "$svc" ] && extra="$svc"
      bt_status 0 "$friendly" "$extra"
    else
      [ "$optional" = "1" ] && extra="optional"
      bt_status 1 "$friendly" "$extra"
    fi
  done
  if bt_php_ext_ok; then
    bt_status 0 "PHP extensions" "pdo_mysql, mbstring, curl, ..."
  else
    bt_status 1 "PHP extensions" "run option 1 to install"
  fi
  # localhost-ssl (a BrineTeam extra)
  if bt_dep_ok "localhost-ssl" ""; then
    bt_status 0 "localhost SSL cert" "$BT_CERTS_DIR"
  else
    bt_status 1 "localhost SSL cert" "optional"
  fi
}

# ---- Service state (for the status column) ---------------------------------
bt_service_state() {
  command -v systemctl >/dev/null 2>&1 || return 0
  case "$1" in
    nginx)      systemctl is-active --quiet nginx && echo "active" || echo "inactive" ;;
    mariadb)    { systemctl is-active --quiet mariadb || systemctl is-active --quiet mysql; } && echo "active" || echo "inactive" ;;
    php|php-fpm)
      local u
      u="$(systemctl list-units --type=service --all 'php*-fpm.service' --no-legend 2>/dev/null | awk '{print $1}' | head -n1)"
      if [ -n "$u" ]; then systemctl is-active --quiet "$u" && echo "active" || echo "inactive"; fi ;;
  esac
}

# ---- Install everything ----------------------------------------------------
bt_install_deps() {
  if ! command -v apt-get >/dev/null 2>&1; then
    bt_err "apt-get not found — this installer targets Ubuntu/Debian."
    return 1
  fi

  bt_ensure_state_dir
  export DEBIAN_FRONTEND=noninteractive
  bt_step "Updating package lists"
  apt-get update -y 2>&1 | tee -a "$BT_LOG_FILE"
  bt_ok "Package lists updated"

  bt_step "Installing base packages"
  bt_info "nginx, mariadb-server, php-fpm + extensions, git, curl, openssl ..."
  # shellcheck disable=SC2086
  if apt-get install -y $BT_APT_PACKAGES 2>&1 | tee -a "$BT_LOG_FILE"; then
    bt_ok "Base packages installed"
  else
    bt_err "Package installation failed — see $BT_LOG_FILE"
    return 1
  fi

  # Optional extras (certbot for real HTTPS)
  if ! bt_dep_ok "certbot" "certbot"; then
    if bt_confirm "Install Certbot (free Let's Encrypt HTTPS)?"; then
      # shellcheck disable=SC2086
      apt-get install -y $BT_APT_OPTIONAL 2>&1 | tee -a "$BT_LOG_FILE" || true
    fi
  fi

  bt_step "Enabling services"
  systemctl enable --now nginx      >/dev/null 2>&1 && bt_ok "nginx enabled"      || bt_warn "could not enable nginx"
  { systemctl enable --now mariadb  >/dev/null 2>&1 || systemctl enable --now mysql >/dev/null 2>&1; } \
    && bt_ok "MariaDB enabled" || bt_warn "could not enable MariaDB"

  local fpm_unit
  fpm_unit="$(systemctl list-unit-files 'php*-fpm.service' --no-legend 2>/dev/null | awk '{print $1}' | head -n1)"
  if [ -n "$fpm_unit" ]; then
    systemctl enable --now "$fpm_unit" >/dev/null 2>&1 && bt_ok "PHP-FPM enabled ($fpm_unit)" || bt_warn "could not enable $fpm_unit"
  else
    bt_warn "php-fpm service not found"
  fi

  bt_step "Setting up localhost SSL certificate"
  bt_install_localhost_ssl

  bt_step "Dependency status"
  bt_print_deps
  bt_log "dependencies installed ($BT_DEPS_OK/$BT_DEPS_TOTAL)"
  return 0
}

# ---- localhost-ssl  (https://github.com/hopingboyz/localhost-ssl) ----------
# Self-signed certificate used for localhost / IP access over HTTPS.
bt_install_localhost_ssl() {
  mkdir -p "$BT_CERTS_DIR"
  if [ -f "$BT_CERTS_DIR/privkey.pem" ] && [ -f "$BT_CERTS_DIR/fullchain.pem" ]; then
    bt_ok "Certificate already present in $BT_CERTS_DIR"
    return 0
  fi
  if ! command -v openssl >/dev/null 2>&1; then
    bt_warn "openssl not available — skipping localhost SSL"
    return 1
  fi
  if openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 \
      -subj "/C=NA/ST=NA/L=NA/O=$BT_COMPANY/CN=localhost" \
      -keyout "$BT_CERTS_DIR/privkey.pem" \
      -out "$BT_CERTS_DIR/fullchain.pem" >>"$BT_LOG_FILE" 2>&1; then
    chmod 600 "$BT_CERTS_DIR/privkey.pem" 2>/dev/null || true
    bt_ok "Self-signed certificate created in $BT_CERTS_DIR"
    return 0
  fi
  bt_warn "could not create certificate"
  return 1
}
