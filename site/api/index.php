<?php
/**
 * JSON API (React front-end backend)
 * ------------------------------------------------------------
 * GET  : public bootstrap (settings, plans, nodes, persons, meta, csrf)
 * POST : admin actions (login / logout / settings / plans / nodes / persons /
 *        payment methods / users / password)
 *
 * Same origin via reverse proxy in dev, and same document root in production,
 * so PHP sessions + uploads work exactly like the admin panel. The database
 * is installed automatically on first run, see lib/db.php.
 */
if (file_exists(__DIR__ . '/../config.php')) {
    require __DIR__ . '/../config.php';
} elseif (file_exists(__DIR__ . '/config.php')) {
    require __DIR__ . '/config.php';
}
require __DIR__ . '/../lib/db.php';

header('Content-Type: application/json; charset=utf-8');

function json_out(array $data, int $code = 200): never
{
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

session_start();

$logined = !empty($_SESSION['admin_id']);
$csrf    = $_SESSION['csrf'] ?? '';
if ($csrf === '') {
    $csrf = bin2hex(random_bytes(16));
    $_SESSION['csrf'] = $csrf;
}

function csrf_ok(?string $token): bool
{
    return $token !== null && hash_equals($_SESSION['csrf'], $token);
}

/* Uploads folder (admin saves uploaded images here). */
$uploadDir = __DIR__ . '/../uploads';
if (!is_dir($uploadDir)) {
    @mkdir($uploadDir, 0755, true);
}
function save_upload_file(string $key, string $dir): ?string
{
    $file = $_FILES[$key] ?? null;
    if (!$file || (int) ($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) {
        return null;
    }
    if ($file['size'] > 3 * 1024 * 1024) {
        return null;
    }
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'ico'], true)) {
        return null;
    }
    $name = $key . '-' . date('Ymd-His') . '-' . bin2hex(random_bytes(4)) . '.' . $ext;
    if (!move_uploaded_file($file['tmp_name'], $dir . DIRECTORY_SEPARATOR . $name)) {
        return null;
    }
    return '/uploads/' . $name;
}

/**
 * Inject the favicon as a base64 data URI into index.html files.
 * Called automatically whenever a new favicon/logo is uploaded.
 */
function inject_favicon_to_html(string $imagePath): void
{
    // $imagePath is like /uploads/favicon-xxx.png — resolve to filesystem path
    $rootDir = dirname(__DIR__);
    $absPath = $rootDir . str_replace('/', DIRECTORY_SEPARATOR, $imagePath);
    if (!file_exists($absPath)) return;

    $ext  = strtolower(pathinfo($absPath, PATHINFO_EXTENSION));
    $mime = match ($ext) {
        'svg'  => 'image/svg+xml',
        'png'  => 'image/png',
        'jpg', 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'ico'  => 'image/x-icon',
        default => 'image/png',
    };
    $b64  = base64_encode(file_get_contents($absPath));
    $uri  = "data:{$mime};base64,{$b64}";

    // Replace any existing icon link, or insert one (there is none by default —
    // the favicon comes only from the uploaded logo/favicon, never baked in).
    $pattern     = '/<link\s+rel="icon"[^>]*\/?>/i';
    $replacement = "<link rel=\"icon\" type=\"{$mime}\" href=\"{$uri}\" />";
    $insert      = function (string $html) use ($replacement): string {
        $matched = preg_replace('/<link\s+rel="icon"[^>]*\/?>/i', $replacement, $html);
        if ($matched !== null && $matched !== $html) {
            return $matched;
        }
        return preg_replace(
            '/<meta\s+name="viewport"[^>]*\/?\s*>/i',
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />\n    {$replacement}",
            $html,
            1,
            $count
        ) ?? $html;
    };

    // List of HTML files to update
    $targets = [
        $rootDir . DIRECTORY_SEPARATOR . 'index.html',
        $rootDir . DIRECTORY_SEPARATOR . 'client' . DIRECTORY_SEPARATOR . 'index.html',
    ];
    foreach ($targets as $file) {
        if (!file_exists($file) || !is_writable($file)) continue;
        $new = $insert(file_get_contents($file));
        if ($new !== file_get_contents($file)) {
            file_put_contents($file, $new);
        }
    }
}

/* ================= Helper to convert node details JSON -> text ============ */
function lines_to_text_json(string $json): string
{
    $arr = json_decode($json, true);
    if (!is_array($arr)) {
        return '';
    }
    $out = [];
    foreach ($arr as $line) {
        $out[] = (is_array($line) && isset($line['label'])) ? $line['label'] . ': ' . ($line['value'] ?? '') : $line;
    }
    return implode("\n", $out);
}

function spec_to_lines_json(string $json): string
{
    $arr = json_decode($json, true);
    return is_array($arr) ? implode("\n", $arr) : '';
}

/* Make a URL-safe slug from a label, e.g. "My VPS Plans" -> "my-vps-plans". */
function slugify(string $text): string
{
    $text = mb_strtolower(trim($text));
    $text = preg_replace('/[^a-z0-9]+/', '-', $text);
    $text = trim((string) $text, '-');
    return $text === '' ? 'cat-' . substr(bin2hex(random_bytes(3)), 0, 6) : $text;
}

/* ================= Bootstrap payload ===================================== */
function bootstrap_payload(bool $includeAdmin = false): array
{
    $settings = settings();
    $payload  = [
        'site_url' => SITE_URL,
        'settings' => $settings,
        'meta'     => [],
        'plans'    => plans(null),
        'categories' => plan_categories(),
        'nodes'    => [],
        'persons'  => contact_persons(),
        'payment_methods' => payment_methods_rows(),
        'csrf'     => $_SESSION['csrf'] ?? '',
        'logged_in' => !empty($_SESSION['admin_id']),
    ];
    foreach (['home', 'plans', 'contact', 'infrastructure', '404'] as $slug) {
        $payload['meta'][$slug] = page_meta($slug);
    }
    foreach (nodes() as $node) {
        $row = $node;
        $row['lines']   = node_lines($node);
        $row['raw']     = lines_to_text_json((string) ($node['details'] ?? ''));
        $payload['nodes'][] = $row;
    }
    if ($includeAdmin) {
        $payload['admin'] = [
            'plan_count' => (int) pdo()->query('SELECT COUNT(*) FROM plans')->fetchColumn(),
            'node_count' => (int) pdo()->query('SELECT COUNT(*) FROM nodes')->fetchColumn(),
            'meta_count' => (int) pdo()->query('SELECT COUNT(*) FROM page_meta')->fetchColumn(),
            'user'       => $_SESSION['admin_user'] ?? '',
            'users'      => array_map(function (array $row): array {
                $row['is_self'] = ((int) $row['id']) === (int) ($_SESSION['admin_id'] ?? 0);
                return $row;
            }, pdo()->query('SELECT id, username, created_at FROM admins ORDER BY id')->fetchAll()),
        ];
    }
    return $payload;
}

$method = $_SERVER['REQUEST_METHOD'];

if ($method === 'GET') {
    json_out(bootstrap_payload(true));
}

if ($method !== 'POST') {
    json_out(['ok' => false, 'message' => 'Method not allowed.'], 405);
}

$action = $_POST['action'] ?? '';

/* ---------------- Login (public) ---------------- */
if ($action === 'login') {
    $u = trim($_POST['username'] ?? '');
    $p = $_POST['password'] ?? '';
    $stmt = pdo()->prepare('SELECT id, username, password_hash FROM admins WHERE username = ?');
    $stmt->execute([$u]);
    $admin = $stmt->fetch();
    if ($admin && password_verify($p, $admin['password_hash'])) {
        session_regenerate_id(true);
        $_SESSION['admin_id']   = (int) $admin['id'];
        $_SESSION['admin_user'] = $admin['username'];
        $_SESSION['csrf']       = bin2hex(random_bytes(16));
        json_out(['ok' => true, 'message' => 'Welcome back, ' . $admin['username'] . '!']);
    }
    json_out(['ok' => false, 'message' => 'Invalid username or password.'], 401);
}

/* ---------------- Everything below requires login + CSRF ---------------- */
if (!$logined) {
    json_out(['ok' => false, 'message' => 'Not logged in.'], 401);
}
if (!csrf_ok($_POST['csrf'] ?? null)) {
    json_out(['ok' => false, 'message' => 'Invalid CSRF token. Please try again.'], 403);
}

switch ($action) {
    case 'logout':
        $_SESSION = [];
        @session_destroy();
        json_out(['ok' => true, 'message' => 'Logged out.', 'logged_in' => false]);

    case 'settings-save':
        $logoUp = save_upload_file('logo', $uploadDir);
        if ($logoUp !== null) {
            $_POST['logo']     = $logoUp;
            $_POST['favicon']  = $logoUp;
            $_POST['og_image'] = $logoUp;
        }
        foreach (['favicon', 'og_image', 'discord_banner_img', 'discord_icon_img', 'hero_bg_img'] as $ik) {
            $up = save_upload_file($ik, $uploadDir);
            if ($up !== null) {
                $_POST[$ik] = $up;
            }
        }
        // Normalize panel URL so the "Open Panel" button always works
        if (isset($_POST['panel_url'])) {
            $pu = trim((string) $_POST['panel_url']);
            if ($pu !== '' && !preg_match('~^https?://~i', $pu)) {
                $_POST['panel_url'] = 'https://' . $pu;
            }
        }
        // Auto-inject favicon into index.html from the uploaded favicon — or the
        // site logo when no separate favicon was uploaded.
        $faviconPath = $_POST['favicon'] ?? '';
        if ($faviconPath === '' && !empty($_POST['logo'])) {
            $faviconPath = $_POST['logo'];
        }
        if ($faviconPath !== '') {
            inject_favicon_to_html($faviconPath);
        }
        $fields = [
            'brand_name', 'logo', 'favicon', 'og_image', 'theme', 'layout', 'theme_color', 'currency_symbol',
            'discord_link', 'hero_badge',
            'discord_banner_img', 'discord_icon_img', 'invite_server_name',
            'panel_url', 'hero_bg_img',
            'footer_blurb', 'footer_copyright',
        ];
        $oldName = s('brand_name', defined('BRAND_NAME') ? BRAND_NAME : '');
        $newName = trim($_POST['brand_name'] ?? '');
        $renameBrand = $oldName !== '' && $newName !== '' && $oldName !== $newName;
        $stmt = pdo()->prepare('INSERT INTO site_settings (key_name, value) VALUES (?, ?)
                                ON DUPLICATE KEY UPDATE value = VALUES(value), updated_at = CURRENT_TIMESTAMP');
        foreach ($fields as $f) {
            if (isset($_POST[$f]) && is_scalar($_POST[$f])) {
                $val = trim((string) $_POST[$f]);
                $stmt->execute([$f, $val]);
            }
        }
        if ($renameBrand) {
            $q = pdo()->prepare('UPDATE page_meta SET title = REPLACE(title, ?, ?), description = REPLACE(description, ?, ?), keywords = REPLACE(keywords, ?, ?)');
            $q->execute([$oldName, $newName, $oldName, $newName, $oldName, $newName]);
            $q2 = pdo()->prepare('UPDATE site_settings SET value = REPLACE(value, ?, ?)');
            $q2->execute([$oldName, $newName]);
        }
        json_out(['ok' => true, 'message' => 'Site settings saved!']);

    case 'person-add':
    case 'person-save':
        $id   = (int) ($_POST['id'] ?? 0);
        $name = trim($_POST['name'] ?? '');
        $role = trim($_POST['role'] ?? '');
        if ($name === '') {
            json_out(['ok' => false, 'message' => 'Person name is required.'], 422);
        }
        $avatarUp = save_upload_file('avatar', $uploadDir);
        if ($id > 0) {
            if ($avatarUp !== null) {
                pdo()->prepare('UPDATE contact_persons SET name = ?, role = ?, avatar = ? WHERE id = ?')->execute([$name, $role, $avatarUp, $id]);
            } else {
                pdo()->prepare('UPDATE contact_persons SET name = ?, role = ? WHERE id = ?')->execute([$name, $role, $id]);
            }
            json_out(['ok' => true, 'message' => 'Person updated.']);
        }
        pdo()->prepare('INSERT INTO contact_persons (name, role, avatar, sort_order) VALUES (?, ?, ?, (SELECT COALESCE(MAX(sort_order),0) + 1 FROM (SELECT sort_order FROM contact_persons) t2))')
            ->execute([$name, $role, $avatarUp ?? '']);
        json_out(['ok' => true, 'message' => 'Person added.']);

    case 'person-move':
        $id  = (int) ($_POST['id'] ?? 0);
        $dir = ($_POST['move_dir'] ?? '') === 'up' ? 'up' : 'down';
        $row = pdo()->prepare('SELECT id, sort_order FROM contact_persons WHERE id = ?');
        $row->execute([$id]);
        $current = $row->fetch();
        if (!$current) {
            json_out(['ok' => false, 'message' => 'Person not found.'], 404);
        }
        $neighbor = null;
        if ($dir === 'up') {
            $n = pdo()->prepare('SELECT id, sort_order FROM contact_persons WHERE sort_order < ? ORDER BY sort_order DESC LIMIT 1');
            $n->execute([$current['sort_order']]);
        } else {
            $n = pdo()->prepare('SELECT id, sort_order FROM contact_persons WHERE sort_order > ? ORDER BY sort_order ASC LIMIT 1');
            $n->execute([$current['sort_order']]);
        }
        $neighbor = $n->fetch();
        if (!$neighbor) {
            json_out(['ok' => false, 'message' => 'Already at the edge.']);
        }
        if ((int) $current['sort_order'] === (int) $neighbor['sort_order']) {
            $norm = pdo()->prepare('SELECT id FROM contact_persons ORDER BY sort_order ASC, id ASC');
            foreach ($norm->fetchAll() as $i => $p) {
                pdo()->prepare('UPDATE contact_persons SET sort_order = ? WHERE id = ?')->execute([$i + 1, $p['id']]);
            }
            $current = pdo()->prepare('SELECT id, sort_order FROM contact_persons WHERE id = ?');
            $current->execute([$id]);
            $current = $current->fetch();
            if ($dir === 'up') {
                $n = pdo()->prepare('SELECT id FROM contact_persons WHERE sort_order < ? ORDER BY sort_order DESC LIMIT 1');
                $n->execute([$current['sort_order']]);
            } else {
                $n = pdo()->prepare('SELECT id FROM contact_persons WHERE sort_order > ? ORDER BY sort_order ASC LIMIT 1');
                $n->execute([$current['sort_order']]);
            }
            $neighbor = $n->fetch();
        }
        $sw = pdo()->prepare('UPDATE contact_persons SET sort_order = ? WHERE id = ?');
        $sw->execute([$current['sort_order'], $neighbor['id']]);
        $sw2 = pdo()->prepare('UPDATE contact_persons SET sort_order = ? WHERE id = ?');
        $sw2->execute([$neighbor['sort_order'], $current['id']]);
        json_out(['ok' => true, 'message' => 'Position updated.']);

    case 'person-delete':
        pdo()->prepare('DELETE FROM contact_persons WHERE id = ?')->execute([(int) ($_POST['id'] ?? 0)]);
        json_out(['ok' => true, 'message' => 'Person removed.']);

    case 'plan-save':
        $id       = (int) ($_POST['id'] ?? 0);
        $cat      = trim($_POST['category'] ?? '');
        if ($cat === '' || !plan_category($cat)) {
            $cat = default_plan_category();
        }
        $name     = trim($_POST['name'] ?? '');
        $price    = max(0, (int) ($_POST['price'] ?? 0));
        $npr      = trim($_POST['npr_label'] ?? '');
        $subtitle = trim($_POST['subtitle'] ?? '');
        $featured = isset($_POST['featured']) ? 1 : 0;
        $order    = (int) ($_POST['sort_order'] ?? 0);
        $rawSpecs = preg_split('/\r\n|\r|\n/', (string) ($_POST['specs'] ?? ''));
        $specs    = [];
        foreach ($rawSpecs as $line) {
            $line = trim($line);
            if ($line !== '') {
                $specs[] = $line;
            }
        }
        $specsJson = json_encode($specs, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($name === '') {
            json_out(['ok' => false, 'message' => 'Plan name is required.'], 422);
        }
        if ($id > 0) {
            pdo()->prepare('UPDATE plans SET category=?, name=?, price=?, npr_label=?, subtitle=?, featured=?, sort_order=?, specs=? WHERE id=?')
                ->execute([$cat, $name, $price, $npr, $subtitle, $featured, $order, $specsJson, $id]);
        } else {
            pdo()->prepare('INSERT INTO plans (category, name, price, npr_label, subtitle, featured, sort_order, specs) VALUES (?,?,?,?,?,?,?,?)')
                ->execute([$cat, $name, $price, $npr, $subtitle, $featured, $order, $specsJson]);
        }
        json_out(['ok' => true, 'message' => 'Plan saved!']);

    case 'plan-delete':
        pdo()->prepare('DELETE FROM plans WHERE id = ?')->execute([(int) ($_POST['id'] ?? 0)]);
        json_out(['ok' => true, 'message' => 'Plan deleted.']);

    case 'category-save':
        $id    = (int) ($_POST['id'] ?? 0);
        $label = trim($_POST['label'] ?? '');
        $type  = in_array($_POST['type'] ?? '', ['hosting', 'vps', 'domain'], true) ? $_POST['type'] : 'hosting';
        $slug  = trim($_POST['slug'] ?? '');
        if ($label === '') {
            json_out(['ok' => false, 'message' => 'Category label is required.'], 422);
        }
        if ($slug === '') {
            $slug = slugify($label);
        } else {
            $slug = slugify($slug);
        }
        $icon  = trim($_POST['icon'] ?? '');
        if ($icon === '' || !preg_match('/^fa-([a-z0-9-]+)$/', $icon)) {
            $icon = ['hosting' => 'fa-server', 'vps' => 'fa-microchip', 'domain' => 'fa-globe'][$type] ?? 'fa-server';
        }
        $order = (int) ($_POST['sort_order'] ?? 0);
        $dup   = pdo()->prepare('SELECT id FROM plan_categories WHERE slug = ? AND id <> ?');
        $dup->execute([$slug, $id]);
        if ($dup->fetch()) {
            json_out(['ok' => false, 'message' => 'A category with this slug already exists: ' . $slug], 422);
        }
        if ($id > 0) {
            pdo()->prepare('UPDATE plan_categories SET slug=?, label=?, type=?, icon=?, sort_order=? WHERE id=?')
                ->execute([$slug, $label, $type, $icon, $order, $id]);
        } else {
            pdo()->prepare('INSERT INTO plan_categories (slug, label, type, icon, sort_order) VALUES (?,?,?,?,?)')
                ->execute([$slug, $label, $type, $icon, $order]);
        }
        json_out(['ok' => true, 'message' => 'Category saved!']);

    case 'category-delete':
        $id  = (int) ($_POST['id'] ?? 0);
        $qt  = pdo()->prepare('SELECT COUNT(*) FROM plans WHERE category = (SELECT slug FROM plan_categories WHERE id = ?)');
        $qt->execute([$id]);
        $count = (int) $qt->fetchColumn();
        if ($count > 0) {
            json_out(['ok' => false, 'message' => $count . ' plan(s) exist in this category — delete or move them first.'], 422);
        }
        pdo()->prepare('DELETE FROM plan_categories WHERE id = ?')->execute([$id]);
        json_out(['ok' => true, 'message' => 'Category deleted.']);

    case 'node-save':
        $id       = (int) ($_POST['id'] ?? 0);
        $name     = trim($_POST['name'] ?? '');
        $status   = trim($_POST['status'] ?? 'ONLINE');
        $order    = (int) ($_POST['sort_order'] ?? 0);
        $rawLines = preg_split('/\r\n|\r|\n/', (string) ($_POST['lines'] ?? ''));
        $lines    = [];
        foreach ($rawLines as $row) {
            $row = trim($row);
            if ($row === '') {
                continue;
            }
            $colon = mb_strpos($row, ':');
            if ($colon !== false) {
                $lines[] = ['label' => trim(mb_substr($row, 0, $colon)), 'value' => trim(mb_substr($row, $colon + 1))];
            } else {
                $lines[] = ['label' => $row, 'value' => ''];
            }
        }
        $linesJson = json_encode($lines, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($name === '') {
            json_out(['ok' => false, 'message' => 'Node name is required.'], 422);
        }
        if ($id > 0) {
            pdo()->prepare('UPDATE nodes SET name=?, status=?, sort_order=?, details=? WHERE id=?')
                ->execute([$name, $status, $order, $linesJson, $id]);
        } else {
            pdo()->prepare('INSERT INTO nodes (name, status, sort_order, details) VALUES (?,?,?,?)')
                ->execute([$name, $status, $order, $linesJson]);
        }
        json_out(['ok' => true, 'message' => 'Node saved!']);

    case 'node-delete':
        pdo()->prepare('DELETE FROM nodes WHERE id = ?')->execute([(int) ($_POST['id'] ?? 0)]);
        json_out(['ok' => true, 'message' => 'Node deleted.']);

    case 'payment-save':
        $id       = (int) ($_POST['id'] ?? 0);
        $name     = trim($_POST['name'] ?? '');
        $order    = (int) ($_POST['sort_order'] ?? 0);
        $bgColor  = trim($_POST['bg_color'] ?? '');
        $bgOpacity = max(0, min(1, (float) ($_POST['bg_opacity'] ?? 1)));
        if ($name === '') {
            json_out(['ok' => false, 'message' => 'Payment method name is required.'], 422);
        }
        $iconUp = save_upload_file('icon', $uploadDir);
        if ($iconUp !== null) {
            $_POST['icon'] = $iconUp;
        }
        $icon = trim($_POST['icon'] ?? '');
        if ($id > 0) {
            if ($icon !== '') {
                pdo()->prepare('UPDATE payment_methods SET name=?, icon=?, bg_color=?, bg_opacity=?, sort_order=? WHERE id=?')
                    ->execute([$name, $icon, $bgColor, $bgOpacity, $order, $id]);
            } else {
                pdo()->prepare('UPDATE payment_methods SET name=?, bg_color=?, bg_opacity=?, sort_order=? WHERE id=?')
                    ->execute([$name, $bgColor, $bgOpacity, $order, $id]);
            }
            json_out(['ok' => true, 'message' => 'Payment method updated.']);
        }
        pdo()->prepare('INSERT INTO payment_methods (name, icon, bg_color, bg_opacity, sort_order) VALUES (?, ?, ?, ?, (SELECT COALESCE(MAX(sort_order),0) + 1 FROM (SELECT sort_order FROM payment_methods) t2))')
            ->execute([$name, $icon, $bgColor, $bgOpacity]);
        json_out(['ok' => true, 'message' => 'Payment method added!']);

    case 'payment-move':
        $id  = (int) ($_POST['id'] ?? 0);
        $dir = ($_POST['move_dir'] ?? '') === 'up' ? 'up' : 'down';
        $row = pdo()->prepare('SELECT id, sort_order FROM payment_methods WHERE id = ?');
        $row->execute([$id]);
        $current = $row->fetch();
        if (!$current) {
            json_out(['ok' => false, 'message' => 'Payment method not found.'], 404);
        }
        $neighbor = null;
        if ($dir === 'up') {
            $n = pdo()->prepare('SELECT id, sort_order FROM payment_methods WHERE sort_order < ? ORDER BY sort_order DESC LIMIT 1');
            $n->execute([$current['sort_order']]);
        } else {
            $n = pdo()->prepare('SELECT id, sort_order FROM payment_methods WHERE sort_order > ? ORDER BY sort_order ASC LIMIT 1');
            $n->execute([$current['sort_order']]);
        }
        $neighbor = $n->fetch();
        if (!$neighbor) {
            json_out(['ok' => false, 'message' => 'Already at the edge.']);
        }
        $sw = pdo()->prepare('UPDATE payment_methods SET sort_order = ? WHERE id = ?');
        $sw->execute([$current['sort_order'], $neighbor['id']]);
        $sw2 = pdo()->prepare('UPDATE payment_methods SET sort_order = ? WHERE id = ?');
        $sw2->execute([$neighbor['sort_order'], $current['id']]);
        json_out(['ok' => true, 'message' => 'Position updated.']);

    case 'payment-delete':
        pdo()->prepare('DELETE FROM payment_methods WHERE id = ?')->execute([(int) ($_POST['id'] ?? 0)]);
        json_out(['ok' => true, 'message' => 'Payment method removed.']);

    case 'security-save':
        $cur  = $_POST['current'] ?? '';
        $new  = $_POST['new'] ?? '';
        $new2 = $_POST['new2'] ?? '';
        $stmt = pdo()->prepare('SELECT password_hash FROM admins WHERE id = ?');
        $stmt->execute([$_SESSION['admin_id']]);
        $row = $stmt->fetch();
        if (!$row || !password_verify($cur, $row['password_hash'])) {
            json_out(['ok' => false, 'message' => 'Current password is incorrect.'], 422);
        }
        if (mb_strlen($new) < 8) {
            json_out(['ok' => false, 'message' => 'New password must be at least 8 characters.'], 422);
        }
        if ($new !== $new2) {
            json_out(['ok' => false, 'message' => 'New passwords do not match.'], 422);
        }
        pdo()->prepare('UPDATE admins SET password_hash = ? WHERE id = ?')
            ->execute([password_hash($new, PASSWORD_DEFAULT), $_SESSION['admin_id']]);
        json_out(['ok' => true, 'message' => 'Password updated!']);

    case 'user-add':
        $u = trim($_POST['username'] ?? '');
        $p = $_POST['password'] ?? '';
        if (!preg_match('/^[a-zA-Z0-9_.-]{3,64}$/', $u)) {
            json_out(['ok' => false, 'message' => 'Username may only contain letters, numbers, . _ - (3–64 chars).'], 422);
        }
        if (mb_strlen($p) < 8) {
            json_out(['ok' => false, 'message' => 'Password must be at least 8 characters.'], 422);
        }
        $exists = pdo()->prepare('SELECT id FROM admins WHERE username = ?');
        $exists->execute([$u]);
        if ($exists->fetch()) {
            json_out(['ok' => false, 'message' => 'Username "' . $u . '" already exists.'], 422);
        }
        pdo()->prepare('INSERT INTO admins (username, password_hash) VALUES (?, ?)')
            ->execute([$u, password_hash($p, PASSWORD_DEFAULT)]);
        json_out(['ok' => true, 'message' => 'Admin user "' . $u . '" created!']);

    case 'user-delete':
        $id = (int) ($_POST['id'] ?? 0);
        if ($id === (int) ($_SESSION['admin_id'] ?? 0)) {
            json_out(['ok' => false, 'message' => 'You cannot delete your own account.'], 422);
        }
        if ((int) pdo()->query('SELECT COUNT(*) FROM admins')->fetchColumn() <= 1) {
            json_out(['ok' => false, 'message' => 'At least one admin account must exist.'], 422);
        }
        pdo()->prepare('DELETE FROM admins WHERE id = ?')->execute([$id]);
        json_out(['ok' => true, 'message' => 'Admin user removed.']);

    default:
        json_out(['ok' => false, 'message' => 'Unknown action: ' . $action], 400);
}