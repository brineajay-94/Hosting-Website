#!/usr/bin/env bash
# ============================================================
#  BrineTeam Installer — configuration & constants
#  BrineStudios  ·  CEO: brineajay
# ============================================================

# ---- Company / branding ----------------------------------------------------
BT_COMPANY="BrineStudios"
BT_PRODUCT="BrineStudios"
BT_CEO="brineajay"
BT_VERSION="1.0.0"
BT_REPO="https://github.com/brineajay-94/Hosting-Website"

# ---- Global command --------------------------------------------------------
BT_CMD="brinestudios"
BT_BIN="/usr/local/bin"

# ---- Where the installer lives / site payload ------------------------------
BT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BT_SITE_SRC="$BT_ROOT/site"

# ---- Install locations on the server ---------------------------------------
BT_WEB_ROOT="/var/www"
BT_STATE_DIR="/etc/brineteam"
BT_STATE_FILE="$BT_STATE_DIR/state.env"
BT_LOG_FILE="$BT_STATE_DIR/install.log"
BT_NGINX_AVAILABLE="/etc/nginx/sites-available"
BT_NGINX_ENABLED="/etc/nginx/sites-enabled"
BT_CERTS_DIR="/etc/certs"          # localhost-ssl (hopingboyz/localhost-ssl)

# ---- Defaults used when the caller does not supply values ------------------
BT_DB_HOST="127.0.0.1"
BT_DEFAULT_BRAND="My Hosting"
BT_DEFAULT_CURRENCY='$'

# ---- Dependency table ------------------------------------------------------
# Format: "key|apt-package|check-command|friendly-name|optional(0/1)"
#  - apt-package: what to install (empty = nothing to install, e.g. config only)
#  - check-command: command that must exist on PATH
BT_DEPS=(
  "git|git|git|Git|0"
  "curl|curl|curl|cURL|0"
  "unzip|unzip|unzip|Unzip|0"
  "openssl|openssl|openssl|OpenSSL|0"
  "nginx|nginx|nginx|Nginx web server|0"
  "mariadb|mariadb-server|mysql|MariaDB server|0"
  "php|php-fpm|php|PHP runtime|0"
  "php-fpm|php-fpm|php-fpm|PHP-FPM service|0"
  "certbot|certbot|certbot|Certbot (Let's Encrypt)|1"
)

# PHP extensions the app needs (checked via `php -m`)
BT_PHP_EXT="pdo_mysql mbstring curl json xml zip gd"

# APT packages installed for the base stack
BT_APT_PACKAGES="nginx mariadb-server php-fpm php-mysql php-curl php-mbstring php-xml php-zip php-gd git curl unzip openssl ca-certificates"
BT_APT_OPTIONAL="certbot python3-certbot-nginx"
