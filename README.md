# Forever Addon Shelf

Installer and download page for a small set of WoW Forever addons.

## Install (Windows)

Download [Install-ForeverAddons.bat](https://github.com/SPEEDB04T/ForeverAddonShelf/releases/latest/download/Install-ForeverAddons.bat) and double-click it. It finds your WoW Forever folder (or asks for it once), shows the addons with what's new, and installs or updates the ones you tick. Run it again any time to update; it can put a shortcut on your desktop for that.

Your browser or Windows may warn about a downloaded script: choose Keep, then More info > Run anyway. The script is plain text, so you can open it in Notepad to read it first.

## Install (Linux)

```bash
bash <(curl -fsSL https://github.com/SPEEDB04T/ForeverAddonShelf/releases/latest/download/install-forever-addons.sh)
```

It looks for WoW Forever in the usual Wine, Lutris, Bottles, Heroic and Steam places (or asks once), then shows the same checklist in a zenity or kdialog window, or in the terminal. Needs `curl` and `unzip`. Options, after the closing bracket: `--text` (terminal only), `--select all` or `--select Name,Name` (no questions), and your World of Warcraft folder if it isn't found.

## What is in this repo

- `addons/<Name>/`: the released source of every addon on the shelf.
- Releases tagged `<Name>-v<version>`: one per addon version, with `<Name>-<version>.zip` attached (one top folder, `<Name>/`). That zip is what the installers and the shelf page download.
- Releases tagged `v<number>`: the installers. The newest one is always the repo's "latest" release, which the install links above point at.
- `addons.tsv`: the list the installers download each time they run (name, title, version, download address, description). Generated; don't edit it by hand.
- `shelf.tsv`: the old list, kept unchanged because installer 3 reads it. Leave it alone.

## Maintaining

### Releasing an addon or a new version

1. Pull this repo.
2. Set `## Version:` in the addon's `.toc` and add the version to its `CHANGELOG.md` (used as the release notes).
3. Run `powershell -NoProfile -File release-addon.ps1 -Name <Name>`. It reads the addon from `..\<Name>` (or `-Source <folder>`), copies it to `addons/<Name>`, publishes the zip as release `<Name>-v<version>`, adds the addon to `addons.config.json` if it is new, rebuilds `addons.tsv`, commits and pushes.
4. Republish the page (below).

Installers already on people's machines show the new version the next time they run. No new installer release is needed.

`-Force` replaces the zip of a version that is already released; `-NoPush` stops before `git push`.

### Republishing the page

`build.ps1` (run by `release-addon.ps1`) writes `site/addons.json`, a copy of every addon file under `site/src/`, and `publish-files.json`, the map of files the page needs. Publish `site/index.html` to the shelf page address in `addons.config.json` (`shelfPage`) with those files. The page then shows the new version, its changelog and its files.

### Changing the installers

Edit `installer.template.bat` or `installer.template.sh`, run `powershell -NoProfile -File build.ps1`, test, commit, push, then attach both files from `dist/` to a new release tagged with the next number and marked latest:

```
gh release create v5 dist\Install-ForeverAddons.bat dist\install-forever-addons.sh --title "Installer 5" --notes "..." --latest
```

The Windows installer's shortcut copy updates itself from the latest release.

### Testing without anything appearing on screen

Windows: set `FOREVER_WOW` to a test folder and `FOREVER_SNAPSHOT` to an empty folder. The window runs off-screen, installs everything, and saves pictures of itself and its timings there. `FOREVER_SELECT=all` runs it in the console instead.

Linux: `bash dist/install-forever-addons.sh --text --select all "<test World of Warcraft folder>"`.
