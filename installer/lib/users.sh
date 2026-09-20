#!/usr/bin/env bash
# ============================================================
#  BrineTeam Installer — admin user management
# ============================================================

# ---- Availability ----------------------------------------------------------
bt_users_available() { bt_site_installed && [ -n "$BT_ST_DB_NAME" ]; }

# ---- Query the site database as the configured user ------------------------
bt_site_sql() { # $1 = SQL
  bt_ensure_state_dir
  local client
  if command -v mariadb >/dev/null 2>&1; then client=mariadb; else client=mysql; fi
  "$client" -h "$BT_DB_HOST" -u "$BT_ST_DB_USER" -p"$BT_ST_DB_PASS" "$BT_ST_DB_NAME" -e "$1" 2>&1
}

# ---- Validate a username (also prevents SQL issues) ------------------------
bt_admin_valid_name() {
  case "$1" in
    ""|*[!A-Za-z0-9._-]*)
      bt_err "Username may only contain letters, numbers, dot, underscore or dash."; return 1 ;;
  esac
  return 0
}

bt_admin_exists() { # $1 username
  bt_site_sql "SELECT username FROM admins WHERE username='$1';" | grep -qx "$1"
}

# ---- List all admins -------------------------------------------------------
bt_admin_list() {
  local out
  out="$(bt_site_sql 'SELECT id AS ID, username AS USERNAME, created_at AS CREATED FROM admins ORDER BY id;')"
  if [ -z "$out" ] || printf '%s' "$out" | grep -qi "doesn't exist\|Unknown table"; then
    bt_warn "No admin users found (is the website installed?)."
    return 1
  fi
  printf '\n%s\n' "${C_BOLD}Admin users${C_RESET}"
  bt_hr
  printf '%s\n' "$out"
  bt_hr
}

# ---- Save (create or update password) --------------------------------------
bt_admin_save() { # $1 username, $2 password
  local out rc
  out="$( cd "$BT_ST_SITE_DIR" && php create-admin.php "$1" "$2" 2>&1 )"; rc=$?
  printf '%s\n' "$out" | tee -a "$BT_LOG_FILE"
  return "$rc"
}

bt_admin_create() {
  bt_step "Create admin user"
  local user pass p2
  user="$(bt_read 'New admin username')"
  bt_admin_valid_name "$user" || return 1
  if bt_admin_exists "$user"; then
    bt_warn "Admin '$user' already exists."
    bt_confirm "Update its password instead?" || return 0
  fi
  while :; do
    pass="$(bt_read_secret 'Password (min 8 chars)')"
    [ "${#pass}" -ge 8 ] || { bt_warn "At least 8 characters."; continue; }
    p2="$(bt_read_secret 'Confirm password')"
    [ "$pass" = "$p2" ] && break
    bt_warn "Passwords did not match."
  done
  if bt_admin_save "$user" "$pass"; then
    bt_ok "Admin '$user' saved."
    bt_log "admin created/updated: $user"
  else
    bt_err "Could not save admin '$user'."
  fi
}

bt_admin_changepw() {
  bt_step "Change admin password"
  bt_admin_list >/dev/null 2>&1
  local user pass p2
  user="$(bt_read 'Username')"
  bt_admin_valid_name "$user" || return 1
  if ! bt_admin_exists "$user"; then
    bt_err "No such admin: '$user'."
    return 1
  fi
  while :; do
    pass="$(bt_read_secret 'New password (min 8 chars)')"
    [ "${#pass}" -ge 8 ] || { bt_warn "At least 8 characters."; continue; }
    p2="$(bt_read_secret 'Confirm password')"
    [ "$pass" = "$p2" ] && break
    bt_warn "Passwords did not match."
  done
  if bt_admin_save "$user" "$pass"; then
    bt_ok "Password updated for '$user'."
    bt_log "admin password changed: $user"
  else
    bt_err "Could not update password."
  fi
}

bt_admin_delete() {
  bt_step "Delete admin user"
  bt_admin_list || return 0
  local user
  user="$(bt_read 'Username to delete')"
  bt_admin_valid_name "$user" || return 1
  if ! bt_admin_exists "$user"; then
    bt_err "No such admin: '$user'."
    return 1
  fi
  bt_confirm "Delete admin '$user'? This cannot be undone." || { bt_warn "Cancelled."; return 0; }
  if bt_site_sql "DELETE FROM admins WHERE username='$user';"; then
    bt_ok "Admin '$user' deleted."
    bt_log "admin deleted: $user"
  else
    bt_err "Could not delete '$user'."
  fi
}

# ---- Submenu ---------------------------------------------------------------
bt_manage_admins() {
  if ! bt_users_available; then
    bt_warn "The website is not installed yet — there is no admin database to manage."
    return 0
  fi
  local running=1
  while [ "$running" -eq 1 ]; do
    bt_step "Manage admin users"
    bt_admin_list
    bt_menu "Admin users" \
      "1:Create new admin user" \
      "2:Change an admin password" \
      "3:Delete an admin user" \
      "0:Back to main menu"
    case "$BT_CHOICE" in
      1) bt_admin_create; bt_pause ;;
      2) bt_admin_changepw; bt_pause ;;
      3) bt_admin_delete; bt_pause ;;
      0) running=0 ;;
      *) bt_warn "Invalid option."; sleep 1 ;;
    esac
  done
}
