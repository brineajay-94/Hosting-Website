<?php
/**
 * One-page setup diagnostic for hosting deploys.
 * Upload to htdocs, open https://yoursite/check.php in a browser,
 * read the report, then DELETE this file once everything is OK.
 *
 * Written in plain PHP 7 syntax on purpose, so it still runs and
 * reports the problem even if the server's PHP is too old for the API.
 */
error_reporting(E_ALL);
ini_set('display_errors', '1');
header('Content-Type: text/html; charset=utf-8');

function row($ok, $label, $detail = '')
{
    $mark = $ok ? '<span style="color:#2fbf71;font-weight:700">OK</span>'
                : '<span style="color:#ff5d5d;font-weight:700">FAIL</span>';
    echo '<tr><td style="padding:6px 14px 6px 0">' . $mark . '</td><td style="padding:6px 14px 6px 0;white-space:nowrap">' . htmlspecialchars($label) . '</td><td style="padding:6px 0;color:#bbb">' . htmlspecialchars($detail) . '</td></tr>';
}

function head($title)
{
    echo '<h2 style="margin:24px 0 8px;border-bottom:1px solid #444;padding-bottom:6px">' . htmlspecialchars($title) . '</h2>';
}

echo '<!doctype html><html><body style="background:#14100b;color:#f6efe6;font:15px/1.6 monospace;padding:30px;max-width:900px;margin:auto">';
echo '<h1 style="font-size:22px">Site deploy diagnostic</h1>';

/* ---------- 1. PHP version ---------- */
head('1. PHP version');
$ver  = PHP_VERSION;
$min  = '8.0.0';
$pass = version_compare($ver, $min, '>=');
row($pass, 'PHP version', $ver . ' — the API (api/index.php) needs PHP 8.0+');
if (!$pass) {
    echo '<p style="color:#ffb84d">This API uses <code>match</code>/<code>never</code> syntax and needs PHP 8.0 or newer.</p>';
}

/* ---------- 2. Files present ---------- */
head('2. Required files present');
row(file_exists(__DIR__ . '/config.php'), 'config.php', __DIR__ . '/config.php');
row(file_exists(__DIR__ . '/api/index.php'), 'api/index.php', '');
row(file_exists(__DIR__ . '/lib/db.php'), 'lib/db.php', '');
row(file_exists(__DIR__ . '/index.html'), 'index.html (SPA)', '');

/* ---------- 3. Config values ---------- */
head('3. config.php values');
$configFile = __DIR__ . '/config.php';
if (file_exists($configFile)) {
    include $configFile;
    $defaults = array('DB_HOST' => array('127.0.0.1', 'localhost'), 'DB_NAME' => array('burncloud'), 'DB_USER' => array('root'), 'DB_PASS' => array(''));
    foreach (array('DB_HOST', 'DB_NAME', 'DB_USER', 'DB_PASS', 'SITE_URL') as $key) {
        $val = defined($key) ? constant($key) : '(not defined)';
        if ($key === 'DB_PASS' && $val !== '(not defined)' && $val !== '') {
            $val = str_repeat('*', min(10, strlen($val)));
        }
        $placeholder = isset($defaults[$key]) && in_array((string) $val, $defaults[$key], true);
        row(!$placeholder, $key, $val . ($placeholder ? '  <- still a placeholder, EDIT config.php' : ''));
    }
} else {
    row(false, 'config.php', 'MISSING - upload it');
}

/* ---------- 4. Database connection ---------- */
head('4. Database connection');
$pdo = null;
if (defined('DB_HOST') && class_exists('PDO')) {
    try {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER,
            DB_PASS,
            array(PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 10)
        );
        row(true, 'PDO connect', 'Connected to ' . DB_NAME);
    } catch (Exception $e) {
        row(false, 'PDO connect', $e->getMessage());
    }
} elseif (!class_exists('PDO')) {
    row(false, 'PDO extension', 'PDO/MySQL driver not loaded');
}

/* ---------- 5. Tables ---------- */
head('5. Tables (auto-installed on first visit)');
if ($pdo) {
    $need = array('site_settings', 'page_meta', 'plans', 'plan_categories', 'nodes', 'contact_persons', 'payment_methods', 'admins');
    $missing = array();
    foreach ($need as $t) {
        $exists = false;
        try {
            $pdo->query('SELECT 1 FROM `' . $t . '` LIMIT 1');
            $exists = true;
        } catch (Exception $e) {
        }
        row($exists, 'table: ' . $t, $exists ? 'found' : 'missing');
        if (!$exists) {
            $missing[] = $t;
        }
    }
    if ($missing) {
        echo '<p style="color:#ffb84d">Tables are auto-created the first time any page calls the API — just load the site once. Or import <strong>database/database.sql</strong> manually.</p>';
    }
    try {
        $n = (int) $pdo->query('SELECT COUNT(*) FROM admins')->fetchColumn();
        row($n > 0, 'admin account', $n . ' admin(s) in `admins` table' . ($n === 0 ? ' - run: php create-admin.php youruser yourpassword' : ''));
    } catch (Exception $e) {
    }
} else {
    echo '<p style="color:#888">(skipped - no DB connection)</p>';
}

/* ---------- 6. Uploads writable ---------- */
head('6. Uploads folder');
$upDir = __DIR__ . '/uploads';
if (!is_dir($upDir)) {
    @mkdir($upDir, 0755, true);
}
row(is_dir($upDir) && is_writable($upDir), 'uploads/ writable', is_writable($upDir) ? 'yes - logo/avatar uploads will work' : 'not writable');

echo '<hr style="border-color:#444"><p style="color:#888">Fix the FAIL rows, reload your site - then <strong>DELETE this check.php</strong>.</p>';
echo '</body></html>';