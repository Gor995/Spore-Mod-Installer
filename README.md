# Spore Mod Installer

A terminal-based mod installer for **Spore on Linux**. Supports `.package` and `.sporemod` files, reads `ModInfo.xml` from bundles to present component descriptions and groups, enforces single-selection within `componentGroup` sets, and auto-installs prerequisite DLLs to [SporeModLoader](https://github.com/Rosalie241/SporeModLoader).

---

## Features

- Interactive TUI menu (full-screen, no scroll history)
- Parses `ModInfo.xml` inside `.sporemod` bundles for display names, descriptions, and component groups
- Groups marked `componentGroup` in the XML display under a labeled header and reject multiple selections from the same group
- Prerequisite DLLs listed in the XML are installed automatically to `SporeModLoader/ModLibs/`
- Standard `.package` files install directly to the Spore `Data/` folder
- Auto-detects Spore's `Data/` folder and SporeModLoader across common Steam and Wine paths
- Falls back to raw file listing when no `ModInfo.xml` is present

---

## Requirements

- `bash` 4.2 or newer
- `unzip` (for `.sporemod` bundles)
- `python3` (stdlib only, for `ModInfo.xml` parsing)
- [SporeModLoader](https://github.com/Rosalie241/SporeModLoader) — required only for mods that ship DLLs

---

## Installation

### Quick setup (run as a command from anywhere)

Download the release zip and extract it. Then copy the script to your local bin directory:

```bash
cp ModInstaller/sporemods.sh ~/.local/bin/sporemods
chmod +x ~/.local/bin/sporemods
```

`~/.local/bin` is included in `$PATH` by default on Fedora and most modern distros. If `sporemods` is not found after this, add the following to your `~/.bashrc` or `~/.bash_profile` and restart your terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

You can then run the installer from any directory:

```bash
sporemods
```

### System-wide installation (optional)

If you want the command available for all users on the machine:

```bash
sudo cp ModInstaller/sporemods.sh /usr/local/bin/sporemods
sudo chmod +x /usr/local/bin/sporemods
```

---

## Usage

1. Extract the release zip and place the `ModInstaller/` folder inside your Spore game directory. The recommended location is:

```
steamapps/common/Spore/ModInstaller/
```

This keeps the installer next to the `Data/` and `SporeModLoader/` folders it writes to, and makes the layout easy to follow. The installer will still work from any location since it auto-detects those paths, but keeping everything under the game directory is cleaner.

2. Drop your `.package` or `.sporemod` files into the `Mods/` folder:

```
steamapps/common/Spore/ModInstaller/
    Mods/          <-- put your mod files here
    sporemods.sh
```

3. Run `sporemods` in the terminal.

4. Select mods by number (space-separated for multiple), `A` to install all, `D` to install defaults only, or `Q` to quit.

After each install the menu redraws. The script does not close until you press `Q`.

---

## .sporemod bundles

When a bundle contains a `ModInfo.xml`, the installer displays the mod's name and description, lists components with their descriptions, and labels component groups:

```
  Rattler SPORE

    A Space Stage overhaul mod for SPORE. ...

  Required DLL(s) - installed automatically:
    -> RattlerSpore.dll

  Components:

    [1] [Package] Rattler SPORE Core v1.1 (default)
        ...

    + Core Recipe Addons  (pick one)
      [2] [Package] Casual Tool Recipes v.1.0
      [3] [Package] Normal Tool Recipes v.1.0 (default)
      [4] [Package] Grindy Tool Recipes v.1.0
    +

    [5] [Package] Rattler SPORE Wares v.1.0
```

Selecting more than one component from the same group is rejected with a clear error. But be careful as some may not be grouped.

When no `ModInfo.xml` is present, the installer falls back to listing the raw files inside the archive.

---

## Detected paths

The installer checks the following locations for Spore's `Data/` folder:

- `/mnt/A/SteamLibrary/steamapps/common/Spore/Data`
- `~/.steam/steam/steamapps/common/Spore/Data`
- `~/.local/share/Steam/steamapps/common/Spore/Data`
- `~/.wine/drive_c/Program Files (x86)/Steam/steamapps/common/Spore/Data`
- `~/.wine/drive_c/Program Files/Steam/steamapps/common/Spore/Data`
- `/Applications/Spore.app/Contents/Resources/Data` (macOS)

If none are found, you will be prompted to enter the path manually.

SporeModLoader is checked in the same Steam library root and common Wine paths.

---

## License

MIT
