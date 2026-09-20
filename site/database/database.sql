-- ============================================================
-- Hosting website — MySQL database
-- ============================================================
-- This file is OPTIONAL. If you import it (phpMyAdmin / `mysql < database.sql`)
-- your database is installed manually. If you skip it, the PHP backend installs
-- the same schema + starter content automatically on the first page load.
--
-- Either way, the starter content is generic — change everything later at
-- /admin (Site Settings, Plans, Nodes, Payment Methods, Team, SEO).
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 1) SITE SETTINGS  (key/value store)
-- ============================================================
CREATE TABLE IF NOT EXISTS site_settings (
  key_name   VARCHAR(64)  NOT NULL,
  value      TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (key_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 2) PAGE SEO  (per-page title / description / keywords)
-- ============================================================
CREATE TABLE IF NOT EXISTS page_meta (
  slug        VARCHAR(40) NOT NULL,
  title       VARCHAR(255),
  description TEXT,
  keywords    TEXT,
  PRIMARY KEY (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 2b) CONTACT TEAM  (multiple persons, reorderable)
-- ============================================================
CREATE TABLE IF NOT EXISTS contact_persons (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(120) NOT NULL,
  role       VARCHAR(120) DEFAULT '',
  avatar     VARCHAR(255) DEFAULT '',
  sort_order INT DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 3) PLAN CATEGORIES  (tabs on the Plans page)
--   type: hosting | vps | domain  (decides plan form/price display)
-- ============================================================
CREATE TABLE IF NOT EXISTS plan_categories (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  slug       VARCHAR(40)  NOT NULL UNIQUE,
  label      VARCHAR(80)  NOT NULL,
  type       VARCHAR(20)  NOT NULL DEFAULT 'hosting',
  icon       VARCHAR(40)  DEFAULT 'fa-server',
  sort_order INT          DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 3b) HOSTING PLANS
--   category: slug from plan_categories
--   specs:    JSON array of specification strings
-- ============================================================
CREATE TABLE IF NOT EXISTS plans (
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 4) INFRASTRUCTURE NODES
--   details: JSON array of {"label":"...","value":"..."}
-- ============================================================
CREATE TABLE IF NOT EXISTS nodes (
  id       INT AUTO_INCREMENT PRIMARY KEY,
  name     VARCHAR(100) NOT NULL,
  status   VARCHAR(40)  DEFAULT 'ONLINE',
  sort_order INT        DEFAULT 0,
  details  TEXT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 5) ADMIN USERS
--   Left empty on purpose: create accounts with create-admin.php
--   (CLI) or at /admin → Users.
-- ============================================================
CREATE TABLE IF NOT EXISTS admins (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(64)  NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ============================================================
-- 6) PAYMENT METHODS (footer "Accepted Payments" icons)
--   icon: path under /uploads/ set from /admin → Payment Methods
-- ============================================================
CREATE TABLE IF NOT EXISTS payment_methods (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  icon       VARCHAR(255) DEFAULT '',
  bg_color   VARCHAR(20)  DEFAULT '',
  bg_opacity DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  sort_order INT DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- STARTER CONTENT (optional demo data — replace at /admin)
-- Adjust the brand/currency lines below to your own brand before
-- importing, or simply leave them and edit at /admin afterwards.
-- ============================================================
INSERT INTO site_settings (key_name, value) VALUES
('brand_name', 'My Hosting'),
('logo', ''),
('favicon', ''),
('og_image', ''),
('theme', 'fire'),
('layout', 'classic'),
('theme_color', '#14100b'),
('currency_symbol', '$'),
('seo_title', 'My Hosting | Premium Hosting'),
('seo_description', 'My Hosting offers reliable server hosting with powerful hardware, fast storage and affordable plans. Get online in minutes.'),
('seo_keywords', 'server hosting, web hosting, vps hosting, domain registration, game server hosting'),
('seo_author', 'My Hosting'),
('discord_link', ''),
('hero_badge', 'Fast & Reliable Hosting'),
('panel_url', ''),
('hero_bg_img', ''),
('discord_banner_img', ''),
('discord_icon_img', ''),
('invite_server_name', 'My Hosting'),
('footer_blurb', 'Premium <strong>server hosting</strong> powered by reliable infrastructure. Affordable, fast, and built for your community.'),
('footer_copyright', '&copy; {year} {brand} &mdash; All rights reserved.');

INSERT INTO page_meta (slug, title, description, keywords) VALUES
('home', 'My Hosting | Premium Hosting',
 'My Hosting offers reliable server hosting with powerful hardware and affordable plans. Get online in minutes.',
 'server hosting, web hosting, hosting plans'),
('plans', 'Hosting Plans | My Hosting',
 'Compare My Hosting plans with simple pricing, powerful hardware and fast disk storage.',
 'hosting plans, vps plans, domain prices, server plans'),
('contact', 'Contact | My Hosting',
 'Contact My Hosting for hosting support, sales questions and help with your server.',
 'contact, hosting support, help, sales'),
('infrastructure', 'Infrastructure | My Hosting',
 'My Hosting infrastructure overview: powerful CPUs, fast NVMe storage and reliable uptime.',
 'infrastructure, servers, datacenter, nvme, uptime'),
('404', '404 | Page Not Found | My Hosting',
 'The page you are looking for could not be found on My Hosting.',
 '404, page not found');

INSERT INTO plan_categories (slug, label, type, icon, sort_order) VALUES
('hosting', 'Hosting Plans', 'hosting', 'fa-server', 1),
('vps', 'VPS Plans', 'vps', 'fa-microchip', 2),
('domains', 'Domains', 'domain', 'fa-globe', 3);

-- Plans and nodes start EMPTY — add them later at /admin (Plans / Nodes).
-- admins and payment_methods also stay empty (create admin via create-admin.php).