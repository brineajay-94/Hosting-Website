# BrineStudios — Hosting Website Installer

**BrineStudios** · CEO: **brineajay** · https://github.com/brineajay-94/Hosting-Website

An interactive installer/menu that sets up and manages a hosting website
(**Nginx + PHP-FPM + MariaDB**) on an Ubuntu/Debian VPS.

## Install

```bash
git clone https://github.com/brineajay-94/Hosting-Website.git
cd Hosting-Website
sudo bash brinestudios.sh
```

After the first run a global command is installed, so you can open the
menu from anywhere:

```bash
sudo brinestudios
```

Then pick:

```
1) Install dependencies     # nginx, PHP-FPM, MariaDB, localhost SSL ...
2) Install website          # asks for URL + admin username/password
```

Log in at `https://your-domain/admin`.

See [INSTALL.md](INSTALL.md) for the full step-by-step guide.

## Menu

- **Not installed:** Install dependencies · Install website · Status · Exit
- **Installed:** Dependencies · Uninstall (frontend / database / both) ·
  Update · Reinstall · **Manage admin users** (list / create / change
  password / delete) · Status · Exit

## Files

```
brinestudios.sh         entry point (the menu) + installs the `brinestudios` command
installer/config.sh     branding, paths, dependency list
installer/lib/ui.sh     banner, colours, menu, prompts
installer/lib/deps.sh   dependency detection + install
installer/lib/site.sh   install / uninstall / update / reinstall
installer/lib/users.sh  admin user management
site/                   the website that gets deployed
```

© BrineStudios · CEO brineajay
