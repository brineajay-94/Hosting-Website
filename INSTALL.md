# Install Guide

## On your VPS (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/brineajay-94/Hosting-Website.git
cd Hosting-Website
sudo bash brineteam.sh
```

## In the menu

```
1) Install dependencies     # nginx, PHP, MariaDB, localhost SSL ...
2) Install website          # asks for URL + admin user/password
```

Then open `https://your-domain/admin` and log in.

## Later

Run `sudo bash brineteam.sh` again any time. If the website is already
installed you get: **Uninstall**, **Update** and **Reinstall** options.
