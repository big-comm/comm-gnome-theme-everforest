#!/usr/bin/env bash
# Helper to apply, refresh, or remove the Everforest theme per user

set -e

THEME_NAME="Everforest-Dark-Medium-B"
WALLPAPER_NAME="bokeh-small-plant.avif"
WALLPAPER_PATH="/usr/share/backgrounds/comm-gnome-theme-everforest/${WALLPAPER_NAME}"
CONFIG_DIR="${HOME}/.config"
CONVERTED_WALLPAPER="${HOME}/.local/share/backgrounds/everforest-wallpaper.jpg"
ACTION="install"

# Color definitions for logs
darkGreen="\e[1;38;5;22m"
lightGreen="\e[1;38;5;34m"
cyan="\e[1;38;5;45m"
white="\e[1;97m"
reset="\e[0m"

printMsg() {
    local message=$1
    echo -e "${darkGreen}[${lightGreen}everforest${darkGreen}]${reset} ${cyan}→${reset} ${white}${message}${reset}"
}

usage() {
    cat <<'EOF'
Usage: install.sh [--install|--upgrade|--uninstall] [--help]

Actions:
  --install, --apply   Apply the Everforest theme for the current user (default)
  --upgrade            Re-apply the theme after a package upgrade
  --uninstall, --remove
                       Remove the theme changes and restore backups if available
  --help               Show this message
EOF
}

backup_config() {
    local file="$1"
    if [ -f "${file}" ]; then
        printMsg "Backing up $(basename "${file}")..."
        cp "${file}" "${file}.backup-$(date +%Y%m%d-%H%M%S)"
    fi
}

restore_backup() {
    local file="$1"
    shopt -s nullglob
    local backups=("${file}.backup-"*)
    shopt -u nullglob

    if [ "${#backups[@]}" -gt 0 ]; then
        local latest="${backups[-1]}"
        cp "${latest}" "${file}"
        printMsg "Restored $(basename "${file}") from $(basename "${latest}")"
    else
        rm -f "${file}"
        printMsg "Removed $(basename "${file}") (no backup found)"
    fi
}

has_backup() {
    compgen -G "${1}.backup-*" > /dev/null 2>&1
}

link_gtk4_assets() {
    printMsg "Linking GTK4 assets..."
    local gtk4_assets="${CONFIG_DIR}/gtk-4.0/assets"
    local theme_assets="/usr/share/themes/${THEME_NAME}/gtk-4.0/assets"

    if [ -d "${theme_assets}" ]; then
        rm -rf "${gtk4_assets}"
        ln -sf "${theme_assets}" "${gtk4_assets}"
    fi

    for css_file in gtk.css gtk-dark.css; do
        if [ -f "/usr/share/themes/${THEME_NAME}/gtk-4.0/${css_file}" ]; then
            rm -f "${CONFIG_DIR}/gtk-4.0/${css_file}"
            ln -sf "/usr/share/themes/${THEME_NAME}/gtk-4.0/${css_file}" "${CONFIG_DIR}/gtk-4.0/${css_file}"
        fi
    done
}

unlink_gtk4_assets() {
    for target in assets gtk.css gtk-dark.css; do
        local path="${CONFIG_DIR}/gtk-4.0/${target}"
        if [ -L "${path}" ] || [ -f "${path}" ]; then
            rm -rf "${path}"
        fi
    done
}

apply_wallpaper() {
    if [ ! -f "${WALLPAPER_PATH}" ]; then
        printMsg "[3/3] Wallpaper file not found at ${WALLPAPER_PATH}"
        return
    fi

    printMsg "[3/3] Setting wallpaper..."
    if command -v heif-convert &>/dev/null; then
        mkdir -p "$(dirname "${CONVERTED_WALLPAPER}")"
        heif-convert "${WALLPAPER_PATH}" "${CONVERTED_WALLPAPER}" >/dev/null
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.background picture-uri "file://${CONVERTED_WALLPAPER}" || true
        fi
    else
        if command -v gsettings &>/dev/null; then
            gsettings set org.gnome.desktop.background picture-uri "file://${WALLPAPER_PATH}" || true
        fi
    fi
}

remove_wallpaper() {
    if [ -f "${CONVERTED_WALLPAPER}" ]; then
        rm -f "${CONVERTED_WALLPAPER}"
        printMsg "Removed converted wallpaper copy"
    fi
    if command -v gsettings &>/dev/null; then
        gsettings reset org.gnome.desktop.background picture-uri || true
    fi
}

apply_theme() {
    printMsg "Installing Everforest Medium Dark Theme"
    echo ""

    local gtk3_config="${CONFIG_DIR}/gtk-3.0/settings.ini"
    local gtk4_config="${CONFIG_DIR}/gtk-4.0/settings.ini"

    printMsg "[1/3] Configuring GTK3 theme..."
    mkdir -p "${CONFIG_DIR}/gtk-3.0"

    if [ -f "${gtk3_config}" ]; then
        backup_config "${gtk3_config}"
        if grep -q "gtk-theme-name" "${gtk3_config}"; then
            sed -i "s/gtk-theme-name=.*/gtk-theme-name=${THEME_NAME}/" "${gtk3_config}"
        else
            echo "gtk-theme-name=${THEME_NAME}" >> "${gtk3_config}"
        fi
    else
        cat >"${gtk3_config}" <<EOF
[Settings]
gtk-theme-name=${THEME_NAME}
gtk-application-prefer-dark-theme=true
EOF
    fi

    printMsg "[2/3] Configuring GTK4 theme..."
    mkdir -p "${CONFIG_DIR}/gtk-4.0"

    if [ -f "${gtk4_config}" ]; then
        backup_config "${gtk4_config}"
        if grep -q "gtk-theme-name" "${gtk4_config}"; then
            sed -i "s/gtk-theme-name=.*/gtk-theme-name=${THEME_NAME}/" "${gtk4_config}"
        else
            echo "gtk-theme-name=${THEME_NAME}" >> "${gtk4_config}"
        fi
    else
        cat >"${gtk4_config}" <<EOF
[Settings]
gtk-theme-name=${THEME_NAME}
gtk-application-prefer-dark-theme=true
EOF
    fi

    link_gtk4_assets
    apply_wallpaper

    echo ""
    printMsg "Installation complete!"
    echo ""
    printMsg "Theme: ${THEME_NAME}"
    echo -e "${white}Use gsettings or GNOME Tweaks if you need to reapply manually.${reset}"
    echo ""
}

remove_theme() {
    printMsg "Removing Everforest theme customizations"
    local gtk3_config="${CONFIG_DIR}/gtk-3.0/settings.ini"
    local gtk4_config="${CONFIG_DIR}/gtk-4.0/settings.ini"

    if [ -f "${gtk3_config}" ] || has_backup "${gtk3_config}"; then
        restore_backup "${gtk3_config}"
    fi

    if [ -f "${gtk4_config}" ] || has_backup "${gtk4_config}"; then
        restore_backup "${gtk4_config}"
    fi

    unlink_gtk4_assets
    remove_wallpaper

    printMsg "Theme settings removed. Re-run with --install to apply again."
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    --install | --apply)
        ACTION="install"
        shift
        ;;
    --upgrade)
        ACTION="upgrade"
        shift
        ;;
    --uninstall | --remove)
        ACTION="remove"
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

case "${ACTION}" in
install)
    apply_theme
    ;;
upgrade)
    printMsg "Re-applying Everforest theme after upgrade"
    apply_theme
    ;;
remove)
    remove_theme
    ;;
*)
    usage
    exit 1
    ;;
esac
