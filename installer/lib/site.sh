#!/usr/bin/env bash
# ============================================================
#  BrineTeam Installer — website install / manage
# ============================================================

# ---- Install state ---------------------------------------------------------
# Populated by bt_load_state; empty when nothing is installed.
BT_ST_INSTALLED=0
BT_ST_DOMAIN=""
BT_ST_SITE_DIR=""
BT_ST_DB_NAME=""
BT_ST_DB_USER=""
BT_ST_DB_PASS=""
BT_ST_ADMIN_USER=""
BT_ST_SSL="none"
BT_ST_DATE=""
BT_ST_SITE_URL=""
BT_ST_BRAND=""
BT_ST_CURRENCY=""
BT_ST_ADMIN_PASS=""

bt_load_state() {
  BT_ST_INSTALLED=0
  if [ -f "$BT_STATE_FILE" ]; then
    # shellcheck disable=SC1090
    . "$BT_STATE_FILE"
    [ -d "$BT_ST_SITE_DIR" ] || BT_ST_INSTALLED=0
  fi
}

bt_save_state() {
  mkdir -p "$BT_STATE_DIR"
  cat >"$BT_STATE_FILE" <<EOF
BT_ST_INSTALLED=$BT_ST_INSTALLED
BT_ST_DOMAIN="$BT_ST_DOMAIN"
BT_ST_SITE_DIR="$BT_ST_SITE_DIR"
BT_ST_DB_NAME="$BT_ST_DB_NAME"
BT_ST_DB_USER="$BT_ST_DB_USER"
BT_ST_DB_PASS="$BT_ST_DB_PASS"
BT_ST_ADMIN_USER="$BT_ST_ADMIN_USER"
BT_ST_SSL="$BT_ST_SSL"
BT_ST_DATE="$BT_ST_DATE"
EOF
  chmod 600 "$BT_STATE_FILE"
}

bt_site_installed() { [ "$BT_ST_INSTALLED" = "1" ] && [ -d "$BT_ST_SITE_DIR" ]; }

# ---- MySQL helpers ---------------------------------------------------------
bt_mysql_root() { # run SQL as root over the local socket
  if command -v mariadb >/dev/null 2>&1; then mariadb -e "$1"; else mysql -e "$1"; fi
}

# Run one or more SQL statements, log output, surface errors. Returns mysql status.
bt_sql() { # $1 = SQL
  bt_ensure_state_dir
  local out rc
  out="$(bt_mysql_root "$1" 2>&1)"; rc=$?
  [ -n "$out" ] && printf '%s\n' "$out" >>"$BT_LOG_FILE"
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$out" >&2
    return "$rc"
  fi
  return 0
}

bt_db_exists() {
  local out
  out="$(bt_mysql_root "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$1';" 2>/dev/null)"
  printf '%s' "$out" | grep -q "$1"
}

bt_db_create() { # $1 db, $2 user, $3 pass
  bt_sql "CREATE DATABASE IF NOT EXISTS \`$1\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || return 1
  bt_sql "CREATE USER IF NOT EXISTS '$2'@'localhost' IDENTIFIED BY '$3';" || return 1
  bt_sql "CREATE USER IF NOT EXISTS '$2'@'127.0.0.1' IDENTIFIED BY '$3';" || return 1
  # Force the password to match config.php (CREATE USER IF NOT EXISTS keeps the old one)
  bt_sql "ALTER USER '$2'@'localhost' IDENTIFIED BY '$3';" || return 1
  bt_sql "ALTER USER '$2'@'127.0.0.1' IDENTIFIED BY '$3';" || return 1
  bt_sql "GRANT ALL PRIVILEGES ON \`$1\`.* TO '$2'@'localhost'; GRANT ALL PRIVILEGES ON \`$1\`.* TO '$2'@'127.0.0.1'; FLUSH PRIVILEGES;" || return 1
}

bt_db_drop() { # $1 db, $2 user
  bt_sql "DROP DATABASE IF EXISTS \`$1\`;" || true
  bt_sql "DROP USER IF EXISTS '$2'@'localhost'; DROP USER IF EXISTS '$2'@'127.0.0.1'; FLUSH PRIVILEGES;" || true
}

# ---- Nginx helpers ---------------------------------------------------------
bt_php_fpm_sock() {
  local s
  s="$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n1)"
  if [ -n "$s" ]; then printf 'unix:%s' "$s"; return; fi
  if command -v php >/dev/null 2>&1; then
    s="/run/php/php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)-fpm.sock"
    [ -S "$s" ] && { printf 'unix:%s' "$s"; return; }
  fi
  printf 'unix:/run/php/php-fpm.sock'
}

bt_write_vhost() { # uses BT_ST_DOMAIN / BT_ST_SITE_DIR / BT_ST_SSL
  local domain="$BT_ST_DOMAIN" dir="$BT_ST_SITE_DIR" sock ssl_cfg="" listen443="" redirect=""
  sock="$(bt_php_fpm_sock)"
  fastcgi="fastcgi_pass $sock;"
  if [ "$BT_ST_SSL" != "none" ] && [ -f "$BT_CERTS_DIR/fullchain.pem" ] && [ "$BT_ST_SSL" = "self" ]; then
    ssl_cfg="    ssl_certificate     $BT_CERTS_DIR/fullchain.pem;
    ssl_certificate_key $BT_CERTS_DIR/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;"
    listen443="    listen 443 ssl;
    listen [::]:443 ssl;"
    redirect="server {
    listen 80;
    listen [::]:80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}
"
  fi

  mkdir -p "$BT_NGINX_AVAILABLE" "$BT_NGINX_ENABLED"
  cat >"$BT_NGINX_AVAILABLE/$domain" <<EOF
# BrineTeam · $BT_COMPANY — managed vhost
$redirect
server {
    listen 80;
    listen [::]:80;
$listen443
    server_name $domain;

    root $dir;
    index index.html index.php;
    client_max_body_size 25M;

$ssl_cfg

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        $fastcgi
    }

    location ~ /\.(?!well-known).* { deny all; }
    location = /config.php { deny all; }
}
EOF
  ln -sf "$BT_NGINX_AVAILABLE/$domain" "$BT_NGINX_ENABLED/$domain"
}

bt_remove_vhost() {
  local domain="$1"
  [ -n "$domain" ] || return 0
  rm -f "$BT_NGINX_ENABLED/$domain" "$BT_NGINX_AVAILABLE/$domain"
  if command -v systemctl >/dev/null 2>&1; then
    nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
  fi
}

bt_nginx_reload() {
  if command -v nginx >/dev/null 2>&1 && nginx -t >/dev/null 2>&1; then
    systemctl reload nginx >/dev/null 2>&1 && bt_ok "Nginx reloaded" || true
  else
    bt_warn "Nginx config test failed — check /etc/nginx"
  fi
}

# ---- Config file -----------------------------------------------------------
bt_write_config() {
  local tpl="$BT_SITE_SRC/config.sample.php" out="$BT_ST_SITE_DIR/config.php"
  [ -f "$tpl" ] || { bt_err "config.sample.php missing in payload"; return 1; }
  sed \
    -e "s|__DB_HOST__|$BT_DB_HOST|g" \
    -e "s|__DB_NAME__|$BT_ST_DB_NAME|g" \
    -e "s|__DB_USER__|$BT_ST_DB_USER|g" \
    -e "s|__DB_PASS__|$BT_ST_DB_PASS|g" \
    -e "s|__SITE_URL__|$BT_ST_SITE_URL|g" \
    -e "s|__BRAND_NAME__|$BT_ST_BRAND|g" \
    -e "s|__CURRENCY_SYMBOL__|$BT_ST_CURRENCY|g" \
    "$tpl" >"$out"
  chmod 640 "$out"
}

# ---- Password generator ----------------------------------------------------
bt_gen_pass() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 24 | tr -dc 'A-Za-z0-9' | cut -c1-18
  else
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 18
  fi
}

# ---- Install inputs --------------------------------------------------------
bt_collect_inputs() {
  bt_step "Website details"
  local url
  url="$(bt_read 'Website URL / domain (e.g. example.com or https://example.com)' "${BT_ST_DOMAIN:-}")"
  [ -n "$url" ] || { bt_err "A domain is required."; return 1; }
  # normalise
  url="${url#http://}"; url="${url#https://}"; url="${url%%/*}"
  BT_ST_DOMAIN="$url"
  BT_ST_SITE_URL="https://$url"
  BT_ST_SITE_DIR="$BT_WEB_ROOT/$url"

  local base
  base="$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '_' | cut -c1-24)"
  BT_ST_DB_NAME="${base}_db"
  BT_ST_DB_USER="${base}_user"

  BT_ST_BRAND="$(bt_read 'Brand / site name' "$BT_DEFAULT_BRAND")"
  BT_ST_CURRENCY="$(bt_read 'Currency symbol' "$BT_DEFAULT_CURRENCY")"

  bt_step "Admin account"
  BT_ST_ADMIN_USER="$(bt_read 'Admin username' "${BT_ST_ADMIN_USER:-admin}")"
  local p1 p2
  while :; do
    p1="$(bt_read_secret 'Admin password (min 8 chars)')"
    if [ "${#p1}" -lt 8 ]; then bt_warn "Password must be at least 8 characters."; continue; fi
    p2="$(bt_read_secret 'Confirm admin password')"
    [ "$p1" = "$p2" ] && break
    bt_warn "Passwords did not match, try again."
  done
  BT_ST_ADMIN_PASS="$p1"

  BT_ST_DB_PASS="$(bt_gen_pass)"

  printf '\n'
  bt_info "Domain      : ${C_BOLD}$BT_ST_DOMAIN${C_RESET}"
  bt_info "Site folder : ${C_BOLD}$BT_ST_SITE_DIR${C_RESET}"
  bt_info "Database    : ${C_BOLD}$BT_ST_DB_NAME${C_RESET} (user $BT_ST_DB_USER)"
  bt_info "Admin user  : ${C_BOLD}$BT_ST_ADMIN_USER${C_RESET}"
  bt_confirm "Proceed with installation?" || { bt_warn "Installation cancelled."; return 1; }
  return 0
}

# ---- Install ---------------------------------------------------------------
bt_install_site() {
  if ! bt_deps_all_ok; then
    bt_warn "Some dependencies are missing. Please run option 1 (Install dependencies) first."
    bt_print_deps
    return 1
  fi

  bt_collect_inputs || return 1

  bt_step "Creating database"
  bt_ensure_state_dir
  if ! bt_sql "SELECT 1;" >/dev/null 2>&1; then
    bt_err "Cannot connect to MariaDB as root over the local socket."
    bt_info "Install/start MariaDB first (menu option 1), then try again."
    return 1
  fi
  if bt_db_exists "$BT_ST_DB_NAME"; then
    bt_warn "Database '$BT_ST_DB_NAME' already exists — reusing it."
  fi
  if ! bt_db_create "$BT_ST_DB_NAME" "$BT_ST_DB_USER" "$BT_ST_DB_PASS"; then
    bt_err "Database setup failed — see $BT_LOG_FILE for details."
    return 1
  fi
  bt_ok "Database ready"

  bt_step "Copying website files"
  mkdir -p "$BT_ST_SITE_DIR"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude 'config.php' --exclude 'uploads' "$BT_SITE_SRC/" "$BT_ST_SITE_DIR/" >>"$BT_LOG_FILE" 2>&1
  else
    find "$BT_ST_SITE_DIR" -mindepth 1 -not -name uploads -not -name config.php -exec rm -rf {} + 2>/dev/null
    cp -a "$BT_SITE_SRC/." "$BT_ST_SITE_DIR/"
  fi
  rm -f "$BT_ST_SITE_DIR/config.sample.php"
  mkdir -p "$BT_ST_SITE_DIR/uploads"
  [ -f "$BT_ST_SITE_DIR/uploads/.keep" ] || : >"$BT_ST_SITE_DIR/uploads/.keep"
  bt_ok "Website files copied to $BT_ST_SITE_DIR"

  bt_step "Writing configuration"
  bt_write_config || return 1
  bt_ok "config.php written"

  bt_step "Installing database schema & admin account"
  if ( cd "$BT_ST_SITE_DIR" && php create-admin.php "$BT_ST_ADMIN_USER" "$BT_ST_ADMIN_PASS" ) >>"$BT_LOG_FILE" 2>&1; then
    bt_ok "Schema installed and admin '$BT_ST_ADMIN_USER' created"
  else
    bt_warn "Could not create the admin account automatically (see $BT_LOG_FILE)."
  fi

  bt_step "Setting permissions"
  chown -R www-data:www-data "$BT_ST_SITE_DIR" 2>/dev/null || true
  find "$BT_ST_SITE_DIR" -type d -exec chmod 755 {} \; 2>/dev/null || true
  find "$BT_ST_SITE_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true
  chmod 640 "$BT_ST_SITE_DIR/config.php" 2>/dev/null || true
  chmod -R 775 "$BT_ST_SITE_DIR/uploads" 2>/dev/null || true
  bt_ok "Permissions set"

  bt_step "Configuring Nginx"
  BT_ST_SSL="none"
  if bt_confirm "Set up HTTPS with a self-signed certificate now?"; then
    BT_ST_SSL="self"
  fi
  bt_write_vhost
  if nginx -t >/dev/null 2>&1; then
    systemctl reload nginx >/dev/null 2>&1 || true
    bt_ok "Nginx vhost enabled for $BT_ST_DOMAIN"
  else
    bt_warn "Nginx config test failed — vhost written but not reloaded."
  fi

  BT_ST_INSTALLED=1
  BT_ST_DATE="$(date '+%Y-%m-%d %H:%M')"
  bt_save_state
  bt_log "website installed: $BT_ST_DOMAIN ($BT_ST_SITE_DIR)"

  bt_show_statistics
}

# ---- Uninstall -------------------------------------------------------------
bt_uninstall_frontend() {
  bt_site_installed || { bt_warn "No website files found to remove."; return 0; }
  bt_confirm "Remove website files at $BT_ST_SITE_DIR (database kept)?" || { bt_warn "Cancelled."; return 0; }
  bt_step "Removing website files"
  rm -rf "$BT_ST_SITE_DIR"
  bt_remove_vhost "$BT_ST_DOMAIN"
  bt_ok "Website files removed"
  # keep DB info in state, mark not installed
  local saved_dir="$BT_ST_SITE_DIR"
  BT_ST_SITE_DIR="$saved_dir"
  BT_ST_INSTALLED=0
  bt_save_state
  bt_log "frontend uninstalled for $BT_ST_DOMAIN"
}

bt_uninstall_database() {
  [ -n "$BT_ST_DB_NAME" ] || { bt_warn "No database recorded."; return 0; }
  bt_confirm "DROP database '$BT_ST_DB_NAME' and its user? This deletes all data!" || { bt_warn "Cancelled."; return 0; }
  bt_step "Dropping database"
  bt_db_drop "$BT_ST_DB_NAME" "$BT_ST_DB_USER"
  bt_ok "Database dropped"
  BT_ST_DB_NAME=""; BT_ST_DB_USER=""; BT_ST_DB_PASS=""
  bt_save_state
  bt_log "database uninstalled"
}

bt_uninstall_site() {
  bt_menu "Uninstall website" \
    "1:Frontend only (keep database)" \
    "2:Database only" \
    "3:Everything (frontend + database)" \
    "0:Back"
  case "$BT_CHOICE" in
    1) bt_uninstall_frontend ;;
    2) bt_uninstall_database ;;
    3) bt_uninstall_frontend; bt_uninstall_database ;;
    *) return 0 ;;
  esac
  # clean up state entirely when nothing is left
  if [ ! -d "$BT_ST_SITE_DIR" ] && [ -z "$BT_ST_DB_NAME" ]; then
    rm -f "$BT_STATE_FILE"
    bt_info "Installation fully removed."
  fi
}

# ---- Update ----------------------------------------------------------------
bt_update_site() {
  bt_site_installed || { bt_warn "Website is not installed."; return 0; }
  bt_step "Updating website files (config & database preserved)"
  # pull latest code when running from a git checkout
  if [ -d "$BT_ROOT/.git" ] && command -v git >/dev/null 2>&1; then
    ( cd "$BT_ROOT" && git pull --ff-only ) >>"$BT_LOG_FILE" 2>&1 && bt_ok "Repository updated" || bt_warn "git pull skipped"
  fi
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude 'config.php' --exclude 'uploads' "$BT_SITE_SRC/" "$BT_ST_SITE_DIR/" >>"$BT_LOG_FILE" 2>&1
  else
    for f in $(cd "$BT_SITE_SRC" && find . -type f); do
      case "$f" in ./config.sample.php) continue;; esac
      mkdir -p "$BT_ST_SITE_DIR/$(dirname "$f")"
      cp -a "$BT_SITE_SRC/$f" "$BT_ST_SITE_DIR/$f"
    done
  fi
  chown -R www-data:www-data "$BT_ST_SITE_DIR" 2>/dev/null || true
  bt_nginx_reload
  bt_ok "Website updated"
  bt_log "website updated: $BT_ST_DOMAIN"
}

# ---- Reinstall -------------------------------------------------------------
bt_reinstall_site() {
  bt_confirm "Reinstall will REMOVE the website and its database, then install fresh. Continue?" \
    || { bt_warn "Cancelled."; return 0; }
  local domain="$BT_ST_DOMAIN" admin="$BT_ST_ADMIN_USER"
  [ -d "$BT_ST_SITE_DIR" ] && rm -rf "$BT_ST_SITE_DIR"
  bt_remove_vhost "$domain"
  [ -n "$BT_ST_DB_NAME" ] && bt_db_drop "$BT_ST_DB_NAME" "$BT_ST_DB_USER"
  rm -f "$BT_STATE_FILE"
  bt_load_state
  BT_ST_DOMAIN="$domain"
  BT_ST_ADMIN_USER="${admin:-admin}"
  bt_info "Starting fresh install..."
  bt_install_site
}

# ---- Statistics ------------------------------------------------------------
bt_show_statistics() {
  bt_deps_count
  printf '\n%s\n' "${C_BOLD}${C_GREEN}Installation summary${C_RESET}"
  bt_hr
  if bt_site_installed; then
    printf '  %-18s %s\n' "Domain"      "$BT_ST_DOMAIN"
    printf '  %-18s %s\n' "Site URL"    "$BT_ST_SITE_URL"
    printf '  %-18s %s\n' "Site folder" "$BT_ST_SITE_DIR"
    printf '  %-18s %s\n' "Database"    "$BT_ST_DB_NAME"
    printf '  %-18s %s\n' "DB user"     "$BT_ST_DB_USER"
    printf '  %-18s %s\n' "Admin user"  "$BT_ST_ADMIN_USER"
    printf '  %-18s %s\n' "HTTPS"       "$BT_ST_SSL"
    printf '  %-18s %s\n' "Installed"   "$BT_ST_DATE"
    printf '  %-18s %s\n' "Admin panel" "${BT_ST_SITE_URL}/admin"
  else
    printf '  %s\n' "${C_YELLOW}Website is not installed.${C_RESET}"
  fi
  bt_hr
  printf '  %-18s %s\n' "Dependencies" "$BT_DEPS_OK/$BT_DEPS_TOTAL required installed"
  printf '  %-18s %s\n' "Server stack" "Nginx · PHP-FPM · MariaDB"
  printf '  %-18s %s\n' "Company"      "$BT_COMPANY (CEO $BT_CEO)"
  bt_hr
}
