<?php
/**
 * Database connection + content helpers for the hosting site.
 * Every PHP entry point includes this file first.
 */
require_once __DIR__ . '/../config.php';

/**
 * Create the database schema and seed basic content on first run.
 * Runs automatically only when the `site_settings` table does not exist yet,
 * so an existing database is never touched. Nothing here changes after the
 * site is installed — edit content later at /admin.
 */
function ensure_schema(PDO $pdo): void
{
    static $checked = false;
    if ($checked) {
        return;
    }
    $checked = true;

    $exists = (int) $pdo->query(
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'site_settings'"
    )->fetchColumn();

    if ($exists > 0) {
        return;
    }

    $pdo->exec('SET FOREIGN_KEY_CHECKS = 0');

    $pdo->exec("CREATE TABLE IF NOT EXISTS site_settings (
        key_name   VARCHAR(64)  NOT NULL,
        value      TEXT,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        PRIMARY KEY (key_name)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS page_meta (
        slug        VARCHAR(40) NOT NULL,
        title       VARCHAR(255),
        description TEXT,
        keywords    TEXT,
        PRIMARY KEY (slug)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS contact_persons (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        name       VARCHAR(120) NOT NULL,
        role       VARCHAR(120) DEFAULT '',
        avatar     VARCHAR(255) DEFAULT '',
        sort_order INT DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS plan_categories (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        slug       VARCHAR(40)  NOT NULL UNIQUE,
        label      VARCHAR(80)  NOT NULL,
        type       VARCHAR(20)  NOT NULL DEFAULT 'hosting',
        icon       VARCHAR(40)  DEFAULT 'fa-server',
        sort_order INT          DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS plans (
        id       INT AUTO_INCREMENT PRIMARY KEY,
        category VARCHAR(40)  NOT NULL,
        name     VARCHAR(100) NOT NULL,
        price    INT          NOT NULL DEFAULT 0,
        npr_label VARCHAR(40) DEFAULT '',
        subtitle VARCHAR(255) DEFAULT '',
        featured TINYINT(1)   DEFAULT 0,
        sort_order INT        DEFAULT 0,
        specs    TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS nodes (
        id       INT AUTO_INCREMENT PRIMARY KEY,
        name     VARCHAR(100) NOT NULL,
        status   VARCHAR(40)  DEFAULT 'ONLINE',
        sort_order INT        DEFAULT 0,
        details  TEXT
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS admins (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        username      VARCHAR(64)  NOT NULL UNIQUE,
        password_hash VARCHAR(255) NOT NULL,
        created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec("CREATE TABLE IF NOT EXISTS payment_methods (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        name       VARCHAR(100) NOT NULL,
        icon       VARCHAR(255) DEFAULT '',
        bg_color   VARCHAR(20)  DEFAULT '',
        bg_opacity DECIMAL(3,2) NOT NULL DEFAULT 1.00,
        sort_order INT DEFAULT 0
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    $pdo->exec('SET FOREIGN_KEY_CHECKS = 1');

    /* ---- Seed: generic starter content (edit later at /admin) ---- */
    $brand  = defined('BRAND_NAME') && BRAND_NAME !== '' ? BRAND_NAME : 'My Hosting';
    $symbol = defined('CURRENCY_SYMBOL') && CURRENCY_SYMBOL !== '' ? CURRENCY_SYMBOL : '$';

    $ins = $pdo->prepare('INSERT INTO site_settings (key_name, value) VALUES (?, ?)');
    $seed = [
        'brand_name' => $brand,
        'logo' => '', 'favicon' => '', 'og_image' => '',
        'theme' => 'fire', 'layout' => 'classic', 'theme_color' => '#14100b',
        'currency_symbol' => $symbol,
        'seo_title' => $brand . ' | Premium Hosting',
        'seo_description' => $brand . ' offers reliable server hosting with powerful hardware, fast storage and affordable plans. Get online in minutes.',
        'seo_keywords' => 'server hosting, web hosting, vps hosting, domain registration, game server hosting',
        'seo_author' => $brand,
        'discord_link' => '',
        'hero_badge' => 'Fast & Reliable Hosting',
        'panel_url' => '',
        'hero_bg_img' => '',
        'discord_banner_img' => '',
        'discord_icon_img' => '',
        'invite_server_name' => $brand,
        'footer_blurb' => 'Premium <strong>server hosting</strong> powered by reliable infrastructure. Affordable, fast, and built for your community.',
        'footer_copyright' => '&copy; {year} {brand} &mdash; All rights reserved.',
    ];
    foreach ($seed as $k => $v) {
        $ins->execute([$k, $v]);
    }

    $insMeta = $pdo->prepare('INSERT INTO page_meta (slug, title, description, keywords) VALUES (?, ?, ?, ?)');
    $metas = [
        ['home', $brand . ' | Premium Hosting', $brand . ' offers reliable server hosting with powerful hardware and affordable plans. Get online in minutes.', 'server hosting, review hosting, hosting plans'],
        ['plans', 'Hosting Plans | ' . $brand, 'Compare ' . $brand . ' hosting plans with simple pricing, powerful hardware and fast disk storage.', 'hosting plans, vps plans, domain prices, server plans'],
        ['contact', 'Contact | ' . $brand, 'Contact ' . $brand . ' for hosting support, sales questions and help with your server.', 'contact, hosting support, help, sales'],
        ['infrastructure', 'Infrastructure | ' . $brand, $brand . ' infrastructure overview: powerful CPUs, fast NVMe storage and reliable uptime.', 'infrastructure, servers, datacenter, nvme, uptime'],
        ['404', '404 | Page Not Found | ' . $brand, 'The page you are looking for could not be found on ' . $brand . '.', '404, page not found'],
    ];
    foreach ($metas as $m) {
        $insMeta->execute($m);
    }

    $pdo->exec("INSERT INTO plan_categories (slug, label, type, icon, sort_order) VALUES
        ('hosting', 'Hosting Plans', 'hosting', 'fa-server', 1),
        ('vps', 'VPS Plans', 'vps', 'fa-microchip', 2),
        ('domains', 'Domains', 'domain', 'fa-globe', 3)");

    /* Plans and nodes start EMPTY — add them later at /admin (Plans / Nodes). */
    /* admins and payment_methods stay empty — add them at /admin. */
}

function pdo(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        try {
            $pdo = new PDO(
                'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
                DB_USER,
                DB_PASS,
                [
                    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                    PDO::ATTR_EMULATE_PREPARES   => false,
                ]
            );
            ensure_schema($pdo);
        } catch (PDOException $e) {
            http_response_code(500);
            exit('<div style="font-family:sans-serif;background:#14100b;color:#f6efe6;min-height:100vh;padding:50px;line-height:1.7">
                <h1>Database connection failed</h1>
                <p>1. Edit <code>config.php</code> and fill in your MySQL / MariaDB details.</p>
                <p>2. Make sure the database exists and the host/user/password match your account.</p>
                <p>3. If the database is brand new it is created automatically &mdash; just load any page again.</p></div>');
        }
    }
    return $pdo;
}

/** Load all site_settings as an associative array (cached). */
function settings(): array
{
    static $s = null;
    if ($s === null) {
        $s = [];
        foreach (pdo()->query('SELECT key_name, value FROM site_settings') as $row) {
            $s[$row['key_name']] = $row['value'];
        }
    }
    return $s;
}

/** Shortcut for a single setting value with default. */
function s(string $key, string $default = ''): string
{
    $v = settings()[$key] ?? null;
    return $v === null || $v === '' ? $default : (string) $v;
}

/** HTML escape. */
function h($value): string
{
    return htmlspecialchars((string) $value, ENT_QUOTES, 'UTF-8');
}

/** Load page_meta row for a slug (or defaults). */
function page_meta(string $slug): array
{
    static $cache = [];
    if (isset($cache[$slug])) {
        return $cache[$slug];
    }
    $q = pdo()->prepare('SELECT title, description, keywords FROM page_meta WHERE slug = ?');
    $q->execute([$slug]);
    $cache[$slug] = $q->fetch() ?: ['title' => '', 'description' => '', 'keywords' => ''];
    return $cache[$slug];
}

/** All plan categories (Plans page tabs), ordered. */
function plan_categories(): array
{
    return pdo()->query('SELECT * FROM plan_categories ORDER BY sort_order ASC, id ASC')->fetchAll();
}

/** Single plan category by slug (or null). */
function plan_category(string $slug): ?array
{
    $q = pdo()->prepare('SELECT * FROM plan_categories WHERE slug = ?');
    $q->execute([$slug]);
    $row = $q->fetch();
    return $row ?: null;
}

/** All plan categories of a given product type (hosting | vps | domain), ordered. */
function plan_categories_by_type(string $type): array
{
    $q = pdo()->prepare('SELECT * FROM plan_categories WHERE type = ? ORDER BY sort_order ASC, id ASC');
    $q->execute([$type]);
    return $q->fetchAll();
}

/** First hosting category slug, or the first category. */
function default_plan_category(): string
{
    foreach (plan_categories() as $cat) {
        if ($cat['type'] === 'hosting') {
            return (string) $cat['slug'];
        }
    }
    $first = plan_categories()[0] ?? null;
    return $first ? (string) $first['slug'] : 'budget';
}

/**
 * Return plans, optionally filtered by category, ordered by sort_order.
 * $limit 0 = all.
 */
function plans(?string $category = null, int $limit = 0): array
{
    $sql = 'SELECT * FROM plans';
    $args = [];
    if ($category !== null) {
        $sql .= ' WHERE category = ?';
        $args[] = $category;
    }
    $sql .= ' ORDER BY sort_order ASC, id ASC';
    if ($limit > 0) {
        $sql .= ' LIMIT ' . (int) $limit;
    }
    $q = pdo()->prepare($sql);
    $q->execute($args);
    return $q->fetchAll();
}

/** The three plans shown on the home page (from the default hosting category). */
function plans_home(): array
{
    $list = plans(default_plan_category(), 3);
    if (count($list) < 3) {
        $list = plans(null, 3);
    }
    return $list;
}

/** Decode a plan's specs JSON into an array of strings. */
function plan_specs(array $plan): array
{
    $decoded = json_decode((string) ($plan['specs'] ?? ''), true);
    return is_array($decoded) ? $decoded : [];
}

/** Pick a FontAwesome icon for a spec line based on its text. */
function spec_icon(string $spec): string
{
    $lower = mb_strtolower($spec);
    if (mb_strpos($lower, 'ram') !== false || mb_strpos($lower, 'memory') !== false) {
        return 'fa-memory';
    }
    if (mb_strpos($lower, 'cpu') !== false || mb_strpos($lower, 'core') !== false || mb_strpos($lower, 'vcore') !== false) {
        return 'fa-microchip';
    }
    if (mb_strpos($lower, 'disk') !== false || mb_strpos($lower, 'nvme') !== false || mb_strpos($lower, 'ssd') !== false) {
        return 'fa-hdd';
    }
    if (mb_strpos($lower, 'location') !== false || mb_strpos($lower, 'region') !== false || mb_strpos($lower, 'datacenter') !== false || mb_strpos($lower, 'location') !== false) {
        return 'fa-map-marker-alt';
    }
    return 'fa-check';
}

/** All infrastructure nodes, ordered. */
function nodes(): array
{
    return pdo()->query('SELECT * FROM nodes ORDER BY sort_order ASC, id ASC')->fetchAll();
}

/** Contact page team members, ordered. */
function contact_persons(): array
{
    return pdo()->query('SELECT * FROM contact_persons ORDER BY sort_order ASC, id ASC')->fetchAll();
}

/** Accepted payment methods (e.g. eSewa, PayPal, etc.), ordered. */
function payment_methods_rows(): array
{
    return pdo()->query('SELECT * FROM payment_methods ORDER BY sort_order ASC, id ASC')->fetchAll();
}

/** Decode a node's details JSON into [ ['label'=>..,'value'=>..], ... ]. */
function node_lines(array $node): array
{
    $decoded = json_decode((string) ($node['details'] ?? ''), true);
    if (!is_array($decoded)) {
        return [];
    }
    $out = [];
    foreach ($decoded as $line) {
        if (is_array($line) && isset($line['label'])) {
            $out[] = ['label' => (string) $line['label'], 'value' => (string) ($line['value'] ?? '')];
        }
    }
    return $out;
}

/**
 * Split a brand name so the LAST word can be highlighted,
 * e.g. "My Host" -> ["My", "Host"].
 */
function brand_split(string $name): array
{
    $name = trim($name);
    if ($name === '') {
        return ['', ''];
    }
    $pos = mb_strrpos($name, ' ');
    if ($pos === false) {
        return ['', $name];
    }
    return [mb_substr($name, 0, $pos), mb_substr($name, $pos + 1)];
}

/** Absolute URL for a stored path/url (assumes same domain). */
function abs_url(string $path): string
{
    if ($path === '') {
        return SITE_URL;
    }
    if (preg_match('~^https?://~i', $path)) {
        return $path;
    }
    return SITE_URL . '/' . ltrim($path, '/');
}

/** Currency symbol + price, e.g. ₹60. */
function price_label(array $plan): string
{
    return s('currency_symbol', '₹') . (int) $plan['price'];
}