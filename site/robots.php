<?php
/*
 * Dynamic robots.txt — serves the Sitemap URL from config.php so it always
 * points at the deployed domain. Do not edit the domain here, edit config.php.
 */
require __DIR__ . '/config.php';

header('Content-Type: text/plain; charset=utf-8');
echo "User-agent: *\n";
echo "Allow: /\n";
echo "Disallow: /admin/\n";
echo "Disallow: /api/\n";
echo "\nSitemap: " . SITE_URL . "/sitemap.php\n";