# Forever Addon Shelf

Installer and download page for a small set of WoW Forever addons.

## Install (Windows)

Download [Install-ForeverAddons.bat](https://github.com/SPEEDB04T/ForeverAddonShelf/releases/latest/download/Install-ForeverAddons.bat) and double-click it. It finds your WoW Forever folder (or asks for it once), shows a checklist of the addons, and installs or updates the ones you tick. Run it again any time to update.

Your browser or Windows may warn about a downloaded script: choose Keep, then More info > Run anyway. The script is plain text, so you can open it in Notepad to read it first.

## Maintaining

- `addons.config.json`: the addons on the shelf (source folder and GitHub repo).
- `build.ps1`: writes `site/addons.json`, the publish file map, and `dist/Install-ForeverAddons.bat` from `installer.template.bat`.
- `site/index.html`: the shelf page.
