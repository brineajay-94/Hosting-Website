# Install Guide

## One-line install (Ubuntu / Debian, as root)

```bash
bash <(curl -s https://raw.githubusercontent.com/brineajay-94/Hosting-Website/main/install.sh)
```

This downloads BrineStudios to `/opt/brinestudios` and opens the menu.
Every later run: `sudo brinestudios`.

### Your own short URL (like `bash <(curl -s https://install.example.com)`)

1. Cloudflare → **Workers & Pages → Create Worker**, paste
   `cloudflare/install-worker.js`, deploy.
2. Add a route / custom domain, e.g. `install.your-domain.com/*`.
3. Then run:

```bash
bash <(curl -s https://install.your-domain.com)
```

## Manual install

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/brineajay-94/Hosting-Website.git
cd Hosting-Website
sudo bash brinestudios.sh
```

## In the menu

```
1) Install dependencies     # nginx, PHP, MariaDB, localhost SSL ...
2) Install website          # asks for URL + admin user/password
```

Then open `https://your-domain/admin` and log in.

## Later

Run `sudo brinestudios` any time. If the website is already installed you
get: **Uninstall**, **Update**, **Reinstall** and **Manage admin users**
options.
