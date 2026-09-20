# BrineTeam — Hosting Website Installer

> **BrineStudios** — building simple, self‑hosted control panels.
> CEO: **brineajay**
> Repository: https://github.com/brineajay-94/Hosting-Website

BrineTeam is a one‑command installer and control menu that installs and
manages a full hosting website (**Nginx + PHP‑FPM + MariaDB**) on an
Ubuntu/Debian VPS. Everything is driven from a single interactive menu
with a big **BrineTeam** banner.

---

## What it does

- Installs and verifies every dependency (Nginx, PHP‑FPM + extensions,
  MariaDB, git, curl, openssl, and optional Certbot).
- Sets up a **localhost SSL** certificate (`/etc/certs`) via OpenSSL.
- Installs the website: prompts for the **website URL**, **admin
  username** and **admin password**, creates the database, writes
  `config.php`, generates the Nginx vhost and creates the admin account.
- Detects state and offers the right actions:
  - **not installed** → install dependencies / install website
  - **installed** → dependencies / uninstall / update / reinstall
- Uninstall supports **frontend only**, **database only**, or **both**.
- Prints a statistics summary (domain, paths, database, admin, HTTPS,
  dependency status).

---

## Requirements

- Ubuntu / Debian VPS (root or `sudo`)
- Internet access for `apt`

## Quick start

```bash
git clone https://github.com/brineajay-94/Hosting-Website.git
cd Hosting-Website
sudo bash brineteam.sh
```

You will see the BrineTeam menu:

```
   ____       _         _____
  | __ ) _ __(_)_ __   |_   _|__  __ _ _ __ ___
  |  _ \| '__| | '_ \    | |/ _ \/ _` | '_ ` _ \
  | |_) | |  | | | | |   | |  __/ (_| | | | | | |
  |____/|_|  |_|_| |_|   |_|\___|\__,_|_| |_| |_|
         Hosting control installer
```

1. **Install dependencies** — packages, services, PHP extensions,
   localhost SSL.
2. **Install website** — enter domain + admin credentials, then wait for
   the summary.
3. Log in at `https://<your-domain>/admin`.

## Layout

```
brineteam.sh              # entry point: opens the BrineTeam menu
installer/
  config.sh               # branding, paths, dependency table
  lib/ui.sh               # banner, colours, menu, prompts, status table
  lib/deps.sh             # dependency detection + installation
  lib/site.sh             # install / uninstall / update / reinstall
site/                     # the website payload that gets deployed
  api/ lib/ database/ assets/ index.html ...
  config.sample.php       # template; the installer writes config.php
```

State is stored in `/etc/brineteam/state.env` (mode `600`); logs go to
`/etc/brineteam/install.log`.

## Manual install (without the menu)

```bash
sudo apt-get install -y nginx mariadb-server php-fpm php-mysql \
     php-curl php-mbstring php-xml php-zip php-gd git curl unzip openssl
sudo cp -r site /var/www/example.com && cd /var/www/example.com
sudo cp config.sample.php config.php   # then edit the values
sudo php create-admin.php admin 'a-strong-password'
```

---

© BrineStudios · CEO brineajay · MIT licensed.
