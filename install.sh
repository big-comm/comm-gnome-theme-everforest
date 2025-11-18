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

# [NEW] Environment variable file for persistent GTK_THEME
ENV_THEME_FILE="${STATE_DIR}/gtk-theme.env"

# [NEW] LibreOffice config for theme detection
LIBREOFFICE_USER_DIR="${HOME}/.config/libreoffice/4/user"
LIBREOFFICE_REGISTRYMODIFICATIONS="${LIBREOFFICE_USER_DIR}/registrymodifications.xcu"

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

  --install, --apply    Apply the Everforest theme for the current user (default)

  --upgrade             Re-apply the theme after a package upgrade

  --uninstall, --remove Remove the theme changes and restore backups if available

  --help                Show this message

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

# [FIX] Sempre salvar o valor anterior, mesmo que arquivo exista
save_gsettings_value() {

local schema="$1" key="$2" file="$3"

[ -n "${file}" ] || return

if command -v gsettings &>/dev/null; then

local value

if value=$(gsettings get "${schema}" "${key}" 2>/dev/null); then

# [CHANGED] Remove a verificação "if ! -s ${file}" para SEMPRE salvar
printf '%s\n' "${value}" > "${file}"

printf '%s %s %s\n' "${schema}" "${key}" "${value}" >> "${STATE_LOG_FILE}" 2>/dev/null || true

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

# [FIX] Sempre salvar o valor anterior ANTES de modificar
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

# [FIX] Garantir que GTK_THEME persista via ~/.profile (shell login)
set_gtk_theme_env() {

printMsg "Setting up GTK_THEME environment variable..."

mkdir -p "$(dirname "${ENV_THEME_FILE}")"

# Create env file that can be sourced
cat > "${ENV_THEME_FILE}" <<EOF
export GTK_THEME=${THEME_NAME}
EOF

printMsg "GTK_THEME environment file created at ${ENV_THEME_FILE}"

# [FIX] Source it for the current session
source "${ENV_THEME_FILE}" 2>/dev/null || true

# [FIX] Ensure it's loaded in shell initialization files - prioritize ~/.profile for login shells
# ~/.profile is read by login shells (like at terminal startup)
# ~/.bashrc is read by interactive non-login shells
# ~/.zshrc is read by zsh interactive shells

# First, always add to ~/.profile (most reliable for login shells)
if [ -f "${HOME}/.profile" ]; then
    if ! grep -q "gtk-theme.env" "${HOME}/.profile"; then
        echo "[ -f \"${ENV_THEME_FILE}\" ] && source \"${ENV_THEME_FILE}\"" >> "${HOME}/.profile"
        printMsg "Added GTK_THEME to ~/.profile"
    fi
fi

# Also add to ~/.bashrc for bash users
if [ -f "${HOME}/.bashrc" ]; then
    if ! grep -q "gtk-theme.env" "${HOME}/.bashrc"; then
        echo "[ -f \"${ENV_THEME_FILE}\" ] && source \"${ENV_THEME_FILE}\"" >> "${HOME}/.bashrc"
        printMsg "Added GTK_THEME to ~/.bashrc"
    fi
fi

# Also add to ~/.zshrc for zsh users
if [ -f "${HOME}/.zshrc" ]; then
    if ! grep -q "gtk-theme.env" "${HOME}/.zshrc"; then
        echo "[ -f \"${ENV_THEME_FILE}\" ] && source \"${ENV_THEME_FILE}\"" >> "${HOME}/.zshrc"
        printMsg "Added GTK_THEME to ~/.zshrc"
    fi
fi

# [FIX] CRITICAL: Also set it for the current session immediately
export GTK_THEME="${THEME_NAME}"

}

# [FIX] Remove GTK_THEME environment variable
unset_gtk_theme_env() {

if [ -f "${ENV_THEME_FILE}" ]; then

rm -f "${ENV_THEME_FILE}"

printMsg "Removed GTK_THEME environment file"

fi

# Remove from shell initialization files
if [ -f "${HOME}/.profile" ]; then

sed -i "\|${ENV_THEME_FILE}|d" "${HOME}/.profile"

fi

if [ -f "${HOME}/.bashrc" ]; then

sed -i "\|${ENV_THEME_FILE}|d" "${HOME}/.bashrc"

fi

if [ -f "${HOME}/.zshrc" ]; then

sed -i "\|${ENV_THEME_FILE}|d" "${HOME}/.zshrc"

fi

unset GTK_THEME

}

# Configure LibreOffice to use the GTK theme
set_libreoffice_theme() {

printMsg "Configuring LibreOffice theme..."

mkdir -p "${LIBREOFFICE_USER_DIR}"

# Create backup of existing registrymodifications.xcu if it exists
if [ -f "${LIBREOFFICE_REGISTRYMODIFICATIONS}" ]; then

backup_config "${LIBREOFFICE_REGISTRYMODIFICATIONS}"

fi

# If registrymodifications.xcu doesn't exist, create a basic one
if [ ! -f "${LIBREOFFICE_REGISTRYMODIFICATIONS}" ]; then

cat > "${LIBREOFFICE_REGISTRYMODIFICATIONS}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://openoffice.org/2001/registry http://openoffice.org/2001/registry.xsd">
</oor:items>
EOF

fi

# Add or update the GTK theme setting for LibreOffice
local gtk_setting='<item oor:path="/org.openoffice.Office.Common/Appearance"><node oor:name="VisualEffect"><value oor:op="fuse">1</value></node></item>'
local theme_setting='<item oor:path="/org.openoffice.Office.Common/Appearance"><node oor:name="Theme"><value oor:op="fuse">0</value></node></item>'

# Check if settings already exist and update them, or add them
if ! grep -q 'oor:path="/org.openoffice.Office.Common/Appearance' "${LIBREOFFICE_REGISTRYMODIFICATIONS}"; then

# Insert before closing tag
sed -i '/<\/oor:items>/i\  '"${gtk_setting}" "${LIBREOFFICE_REGISTRYMODIFICATIONS}"

fi

# Force dark mode preference in LibreOffice
local dark_mode_setting='<item oor:path="/org.openoffice.Office.Common/Appearance"><node oor:name="DarkMode"><value oor:op="fuse">true</value></node></item>'

if ! grep -q 'DarkMode' "${LIBREOFFICE_REGISTRYMODIFICATIONS}"; then

sed -i '/<\/oor:items>/i\  '"${dark_mode_setting}" "${LIBREOFFICE_REGISTRYMODIFICATIONS}"

fi

printMsg "LibreOffice configuration updated"

}

# Remove LibreOffice theme configuration
unset_libreoffice_theme() {

if [ -f "${LIBREOFFICE_REGISTRYMODIFICATIONS}" ]; then

restore_backup "${LIBREOFFICE_REGISTRYMODIFICATIONS}"

else

printMsg "LibreOffice registry not found or already restored"

fi

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

if heif-convert "${WALLPAPER_PATH}" "${CONVERTED_WALLPAPER}" >/dev/null 2>&1; then

target_path="${CONVERTED_WALLPAPER}"

else

printMsg "Warning: heif-convert failed; using AVIF directly."

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

# [FIX] Now save_gsettings_value is called inside set_gsettings_with_backup
# This ensures we ALWAYS capture the previous theme before modifying
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

if grep -q "gtk-application-prefer-dark-theme" "${gtk4_config}"; then

sed -i "s/gtk-application-prefer-dark-theme=.*/gtk-application-prefer-dark-theme=true/" "${gtk4_config}"

else

echo "gtk-application-prefer-dark-theme=true" >> "${gtk4_config}"

fi

else

cat >"${gtk4_config}" <<EOF
[Settings]
gtk-application-prefer-dark-theme=true
EOF

fi

link_gtk4_assets

apply_gsettings_theme

set_libreoffice_theme

set_gtk_theme_env

apply_wallpaper

echo ""

printMsg "Everforest theme successfully applied!"

echo ""

printMsg "Note: File dialogs (GTK File Chooser) and LibreOffice now use the dark theme."

printMsg "Restart LibreOffice or reload shell for environment changes to take full effect."

}

remove_theme() {

printMsg "Removing Everforest theme..."

echo ""

local gtk3_config="${CONFIG_DIR}/gtk-3.0/settings.ini"

local gtk4_config="${CONFIG_DIR}/gtk-4.0/settings.ini"

restore_backup "${gtk3_config}"

restore_backup "${gtk4_config}"

unlink_gtk4_assets

remove_wallpaper

unset_libreoffice_theme

unset_gtk_theme_env

echo ""

printMsg "Everforest theme successfully removed!"

}

# Main script logic

case "${1:-}" in

--install|--apply)

apply_theme

;;

--upgrade)

printMsg "Upgrading Everforest theme..."

remove_theme

apply_theme

;;

--uninstall|--remove)

remove_theme

;;

--help)

usage

;;

"")

apply_theme

;;

*)

echo "Unknown option: $1"

usage

exit 1

;;

esac
