<?php
/*
 * Dynamic sitemap.xml — built from config.php so it always uses the deployed
 * domain. Optional extra pages can be added to $pages below.
 */
require __DIR__ . '/config.php';

header('Content-Type: application/xml; charset=utf-8');
$base = rtrim(SITE_URL, '/');
$pages = ['', 'plans', 'contact', 'infrastructure'];

echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' . "\n";
foreach ($pages as $p) {
    $loc = $base . ($p ? '/' . $p : '') . '/';
    echo "  <url><loc>" . htmlspecialchars($loc, ENT_XML1, 'UTF-8') . "</loc><changefreq>weekly</changefreq></url>\n";
}
echo '</urlset>' . "\n";