# Install Guide

## On your VPS (Ubuntu / Debian)

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/brineajay-94/Hosting-Website.git
cd Hosting-Website
sudo bash brinestudios.sh
```

The first run installs a global command, so afterwards you can just run:

```bash
sudo brinestudios
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
