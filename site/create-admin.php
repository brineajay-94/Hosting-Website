<?php
/**
 * Hosting site — create an admin account from the command line.
 *
 * Usage (local work):
 *     php create-admin.php yourusername yourpassword
 *
 * It prints the bcrypt hash too, so you can insert the same account
 * manually on the live site (e.g. phpMyAdmin on InfinityFree):
 *     INSERT INTO admins (username, password_hash) VALUES ('myuser', '<hash>');
 */
require __DIR__ . '/lib/db.php';

$argc = $argc ?? count($argv ?? []);
$argv = $argv ?? [];

if ($argc < 3) {
    echo "Usage: php create-admin.php <username> <password>\n";
    echo "       php create-admin.php --hash <password>   (prints hash only)\n";
    exit(1);
}

if ($argv[1] === '--hash') {
    echo password_hash($argv[2], PASSWORD_DEFAULT) . "\n";
    exit(0);
}

$username = trim($argv[1]);
$password = $argv[2];

if ($username === '') {
    echo "Error: username cannot be empty.\n";
    exit(1);
}
if (mb_strlen($password) < 8) {
    echo "Error: password must be at least 8 characters.\n";
    exit(1);
}

$hash = password_hash($password, PASSWORD_DEFAULT);

try {
    $stmt = pdo()->prepare('SELECT id FROM admins WHERE username = ?');
    $stmt->execute([$username]);
    if ($stmt->fetch()) {
        $upd = pdo()->prepare('UPDATE admins SET password_hash = ? WHERE username = ?');
        $upd->execute([$hash, $username]);
        echo "Admin '$username' already existed — password updated.\n";
    } else {
        $ins = pdo()->prepare('INSERT INTO admins (username, password_hash) VALUES (?, ?)');
        $ins->execute([$username, $hash]);
        echo "Admin '$username' created.\n";
    }
    echo "Hash: $hash\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
    exit(1);
}