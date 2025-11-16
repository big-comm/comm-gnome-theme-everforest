#!/usr/bin/env bash
# Helper to apply, refresh, or remove the Everforest theme per user

set -e

THEME_NAME="Everforest-Dark-Medium-B"
WALLPAPER_NAME="bokeh-small-plant.avif"
WALLPAPER_PATH="/usr/share/backgrounds/comm-gnome-theme-everforest/${WALLPAPER_NAME}"
CONFIG_DIR="${HOME}/.config"
STATE_DIR="${CONFIG_DIR}/comm-gnome-theme-everforest"
STATE_USER_THEME_FILE="${STATE_DIR}/prev-user-theme"
STATE_GTK_THEME_FILE="${STATE_DIR}/prev-gtk-theme"
STATE_COLOR_FILE="${STATE_DIR}/prev-color-scheme"
STATE_WALL_FILE="${STATE_DIR}/prev-wallpaper"
STATE_WALL_DARK_FILE="${STATE_DIR}/prev-wallpaper-dark"
STATE_LOG_FILE="${STATE_DIR}/gsettings-backups.log"
CONVERTED_WALLPAPER="${HOME}/.local/share/backgrounds/everforest-wallpaper.jpg"
ACTION="install"
_backup_suffix="$(date +%Y%m%d-%H%M%S)"

mkdir -p "${STATE_DIR}" 2>/dev/null || true

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
    if [ ! -f "${file}" ]; then
        return
    fi

    local dest="${file}.backup-${_backup_suffix}"
    if cp "${file}" "${dest}"; then
        printMsg "Backing up $(basename "${file}")..."
    else
        printMsg "Warning: Failed to backup $(basename "${file}") (permission denied?)."
    fi
}

restore_backup() {
    local file="$1"
    shopt -s nullglob
    local backups=("${file}.backup-"*)
    shopt -u nullglob

    if [ "${#backups[@]}" -gt 0 ]; then
        local latest="${backups[-1]}"
        if cp "${latest}" "${file}"; then
            printMsg "Restored $(basename "${file}") from $(basename "${latest}")"
        else
            printMsg "Warning: Failed to restore $(basename "${file}") from $(basename "${latest}")"
        fi
    else
        if rm -f "${file}"; then
            printMsg "Removed $(basename "${file}") (no backup found)"
        fi
    fi
}

has_backup() {
    compgen -G "${1}.backup-*" > /dev/null 2>&1
}

save_gsettings_value() {
    local schema="$1" key="$2" file="$3"
    [ -n "${file}" ] || return
    if command -v gsettings &>/dev/null; then
        if [ ! -s "${file}" ]; then
            local value
            if value=$(gsettings get "${schema}" "${key}" 2>/dev/null); then
                printf '%s\n' "${value}" > "${file}"
                printf '%s %s %s\n' "${schema}" "${key}" "${value}" >> "${STATE_LOG_FILE}"
            fi
        fi
    fi
}

restore_gsettings_value() {
    local schema="$1" key="$2" file="$3"
    if command -v gsettings &>/dev/null && [ -s "${file}" ]; then
        local value
        value=$(cat "${file}")
        if gsettings set "${schema}" "${key}" "${value}"; then
            printMsg "Restored ${schema} ${key} to ${value}"
        else
            printMsg "Warning: Failed to restore ${schema} ${key}."
        fi
        rm -f "${file}"
    fi
}

set_gsettings_with_backup() {
    local schema="$1" key="$2" target_value="$3" backup_file="$4" description="$5"
    if ! command -v gsettings &>/dev/null; then
        printMsg "gsettings unavailable; skipping ${schema} ${key}."
        return 1
    fi

    save_gsettings_value "${schema}" "${key}" "${backup_file}"
    if gsettings set "${schema}" "${key}" "${target_value}"; then
        if [ -n "${description}" ]; then
            printMsg "${description}"
        fi
        return 0
    else
        printMsg "Warning: Failed to set ${schema} ${key}."
        return 1
    fi
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
    local target_path="${WALLPAPER_PATH}"
    if command -v heif-convert &>/dev/null; then
        mkdir -p "$(dirname "${CONVERTED_WALLPAPER}")"
        if heif-convert "${WALLPAPER_PATH}" "${CONVERTED_WALLPAPER}" >/dev/null; then
            target_path="${CONVERTED_WALLPAPER}"
        else
            printMsg "Warning: heif-convert failed; wallpaper not converted."
        fi
    fi

    local uri="'file://${target_path}'"
    set_gsettings_with_backup \
        org.gnome.desktop.background picture-uri "${uri}" "${STATE_WALL_FILE}" \
        "Wallpaper set for light mode." || printMsg "Wallpaper file installed manually."

    set_gsettings_with_backup \
        org.gnome.desktop.background picture-uri-dark "${uri}" "${STATE_WALL_DARK_FILE}" \
        "Wallpaper set for dark mode." || true
}

remove_wallpaper() {
    if [ -f "${CONVERTED_WALLPAPER}" ]; then
        rm -f "${CONVERTED_WALLPAPER}"
        printMsg "Removed converted wallpaper copy"
    fi
    restore_gsettings_value org.gnome.desktop.background picture-uri "${STATE_WALL_FILE}"
    restore_gsettings_value org.gnome.desktop.background picture-uri-dark "${STATE_WALL_DARK_FILE}"
}

apply_gsettings_theme() {
    if ! command -v gsettings &>/dev/null; then
        printMsg "gsettings not available; skipping GNOME interface update."
        return
    fi

    local theme_value="'${THEME_NAME}'"
    set_gsettings_with_backup \
        org.gnome.shell.extensions.user-theme name "${theme_value}" "${STATE_USER_THEME_FILE}" \
        "Shell user-theme set to ${THEME_NAME}." || true

    set_gsettings_with_backup \
        org.gnome.desktop.interface gtk-theme "${theme_value}" "${STATE_GTK_THEME_FILE}" \
        "GNOME interface theme set to ${THEME_NAME}."

    set_gsettings_with_backup \
        org.gnome.desktop.interface color-scheme "'prefer-dark'" "${STATE_COLOR_FILE}" \
        "Color scheme set to prefer-dark."
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
    apply_gsettings_theme

    echo ""
    printMsg "Installation complete!"
    echo ""
    printMsg "Theme: ${THEME_NAME}"
    echo -e "${white}Use gsettings or GNOME Tweaks if you need to reapply manually.${reset}"
    echo ""

    # Configurar color-scheme para dark
    if gsettings writable org.gnome.desktop.interface color-scheme >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        printMsg "${lightGreen}Color scheme set to prefer-dark${reset}"
    fi
    
    # Reiniciar portais para aplicar mudanças
    killall xdg-desktop-portal-gtk 2>/dev/null || true
    killall xdg-desktop-portal-gnome 2>/dev/null || true

        # Fix para Loupe
    if command -v loupe >/dev/null 2>&1; then
        local loupe_desktop="/usr/share/applications/org.gnome.Loupe.desktop"
        
        if [ -f "${loupe_desktop}" ]; then
            # Backup do original
            cp "${loupe_desktop}" "${loupe_desktop}.bak"
            
            # Modificar Exec para forçar tema
            sed -i 's|Exec=|Exec=env GTK_THEME=Everforest-Dark-Medium-B:dark SAL_USE_VCLPLUGIN=gtk4 |' "${loupe_desktop}"
        fi
    fi

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
    restore_gsettings_value org.gnome.desktop.interface gtk-theme "${STATE_GTK_THEME_FILE}"
    restore_gsettings_value org.gnome.desktop.interface color-scheme "${STATE_COLOR_FILE}"
    restore_gsettings_value org.gnome.shell.extensions.user-theme name "${STATE_USER_THEME_FILE}"

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
