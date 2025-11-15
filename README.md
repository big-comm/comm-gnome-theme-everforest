# comm-gnome-theme-everforest

Everforest Medium Dark is a GNOME theme inspired by the Everforest palette, providing GTK3/GTK4 styles, libadwaita assets, and a curated wallpaper. This repository ships the customized build used by the BigLinux community.

## What's included
- Automated build of the upstream [Fausto-Korpsvart/Everforest-GTK-Theme](https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme) using the `Dark + Medium` tweaks.
- Wallpaper `bokeh-small-plant.avif` installed in `/usr/share/backgrounds/comm-gnome-theme-everforest/`.
- Helper script (`/usr/share/comm-gnome-theme-everforest/install.sh`) to apply, refresh, or remove user-level tweaks.

## Key dependencies
- Runtime: `gtk3`, `gtk4`, `gnome-shell`, `gtk-engine-murrine`.
- Build: `git`, `sassc`.
- Optional: `heif` to convert the AVIF wallpaper automatically when applying it.

## Helper usage
During `pacman` install/upgrade/remove the helper runs automatically for the active graphical user (detected through `sudo`, `logname`, or `loginctl`). You can still run it manually to reapply changes or affect other accounts.

### Apply (initial installation)
```bash
/usr/share/comm-gnome-theme-everforest/install.sh
```

### Refresh after package upgrades
```bash
/usr/share/comm-gnome-theme-everforest/install.sh --upgrade
```

### Remove customizations
```bash
/usr/share/comm-gnome-theme-everforest/install.sh --uninstall
```

The helper backs up `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` before making changes and restores the latest backup during removal when available. If no graphical session is detected during `pacman -S/-R`, you will only see a warning and can execute the commands above manually.

### Available options
```
--install, --apply   Apply the theme (default)
--upgrade            Reapply the theme after a package update
--uninstall, --remove
                     Remove settings and restore backups
--help               Show usage information
```

## Build process
The `PKGBUILD` pulls two sources:
1. `Everforest-GTK-Theme`: compiled via `themes/install.sh --dest "$srcdir/theme-build" --color dark --tweaks medium`.
2. This repository (`comm-gnome-theme-everforest`): provides the helper, wallpaper, and documentation.

During `package()` the following are installed:
- `/usr/share/themes/Everforest-Dark-Medium-B` (generated theme files).
- `/usr/share/comm-gnome-theme-everforest/install.sh` (mode 755).
- Documentation and license under `/usr/share/doc` and `/usr/share/licenses`.
- Wallpapers under `/usr/share/backgrounds/comm-gnome-theme-everforest/`.

## Credits
- Original theme: [Fausto-Korpsvart](https://github.com/Fausto-Korpsvart).
- Packaging: BigLinux Community.
