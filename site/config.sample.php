<?php
/**
 * ============================================================
 *  Site configuration template.
 * ============================================================
 *  This file is a TEMPLATE. The BrineTeam installer replaces the
 *  __PLACEHOLDER__ values below and writes the real `config.php`
 *  into your site directory automatically — you do not edit this
 *  file by hand when using the installer.
 *
 *  (If you prefer a manual install, copy this file to config.php
 *   and fill in the values yourself.)
 * ============================================================
 */

/* ---- MySQL / MariaDB credentials -------------------------------------- */
define('DB_HOST', '__DB_HOST__');
define('DB_NAME', '__DB_NAME__');
define('DB_USER', '__DB_USER__');
define('DB_PASS', '__DB_PASS__');

/* ---- Public URL of the site (no trailing slash) ------------------------ */
define('SITE_URL', '__SITE_URL__');

/* ---- Brand defaults used when the site is first installed -------------- */
/* These only fill the initial database seed — change them any time later
   from /admin → Site Settings. */
define('BRAND_NAME', '__BRAND_NAME__');
define('CURRENCY_SYMBOL', '__CURRENCY_SYMBOL__');

/* ---- Developer switch --------------------------------------------------- */
/* Errors stay off on a live server; flip to '1' temporarily to debug. */
ini_set('display_errors', '0');
error_reporting(E_ALL & ~E_DEPRECATED & ~E_NOTICE);
