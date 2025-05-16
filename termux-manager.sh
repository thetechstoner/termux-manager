#!/bin/bash
check_storage() {
  if [ ! -d $HOME/storage ]; then
    termux-setup-storage
  fi
}
install_repos() {
    # Detect package manager
    local pkg_manager
    if command -v pacman >/dev/null 2>&1 && [ -f "$PREFIX/etc/pacman.conf" ]; then
        pkg_manager="pacman"
    else
        pkg_manager="pkg"
    fi

    # Process each requested repo
    for repo in ${repos}; do
        case $repo in
            "tur-repo")
                if [ "$pkg_manager" = "pkg" ]; then
                    # Termux (apt) installation
                    if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
                        pkg install -y tur-repo || {
                            echo "Failed to install tur-repo" >&2
                            return 1
                        }
                    fi
                else
                    # Termux-pacman installation
                    echo "Adding tur repository for pacman..."
                    if ! grep -q "^\[tur\]" "$PREFIX/etc/pacman.conf" 2>/dev/null; then
                        echo -e "\n[tur]\nServer = https://termux-pacman.dev/tur/\$arch" >> "$PREFIX/etc/pacman.conf" && \
                        pacman -Sy || {
                            echo "Failed to add tur repository" >&2
                            return 1
                        }
                    fi
                fi
                ;;

            "glibc-repo")
                if [ "$pkg_manager" = "pkg" ]; then
                    # Termux (apt) installation
                    if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
                        pkg install -y glibc-repo || {
                            echo "Failed to install glibc-repo" >&2
                            return 1
                        }
                    fi
                else
                    # Termux-pacman installation
                    echo "Adding gpkg repository for pacman..."
                    if ! grep -q "^\[gpkg\]" "$PREFIX/etc/pacman.conf" 2>/dev/null; then
                        echo -e "\n[gpkg]\nServer = https://termux-pacman.dev/gpkg/\$arch" >> "$PREFIX/etc/pacman.conf" && \
                        pacman -Sy || {
                            echo "Failed to add gpkg repository" >&2
                            return 1
                        }
                    fi
                fi
                ;;

            "x11-repo")
                if [ "$pkg_manager" = "pkg" ]; then
                    # Termux (apt) installation
                    if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
                        pkg install -y x11-repo || {
                            echo "Failed to install x11-repo" >&2
                            return 1
                        }
                    fi
                else
                    # Termux-pacman installation
                    echo "Adding x11 repository for pacman..."
                    if ! grep -q "^\[x11\]" "$PREFIX/etc/pacman.conf" 2>/dev/null; then
                        echo -e "\n[x11]\nServer = https://termux-pacman.dev/x11/\$arch" >> "$PREFIX/etc/pacman.conf" && \
                        pacman -Sy || {
                            echo "Failed to add x11 repository" >&2
                            return 1
                        }
                    fi
                fi
                ;;

            "root-repo")
                if [ "$pkg_manager" = "pkg" ]; then
                    # Termux (apt) installation
                    if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
                        pkg install -y root-repo || {
                            echo "Failed to install root-repo" >&2
                            return 1
                        }
                    fi
                else
                    # Termux-pacman installation
                    echo "Adding root repository for pacman..."
                    if ! grep -q "^\[root\]" "$PREFIX/etc/pacman.conf" 2>/dev/null; then
                        echo -e "\n[root]\nServer = https://termux-pacman.dev/root/\$arch" >> "$PREFIX/etc/pacman.conf" && \
                        pacman -Sy || {
                            echo "Failed to add root repository" >&2
                            return 1
                        }
                    fi
                fi
                ;;

            *)
                echo "Unknown repository: $repo" >&2
                ;;
        esac
    done

    return 0
}
install_if_missing() {
    # Detect package manager
    local pkg_manager
    if command -v pacman >/dev/null 2>&1 && [ -f "$PREFIX/etc/pacman.conf" ]; then
        pkg_manager="pacman"
    else
        pkg_manager="pkg"
    fi

    # Common package mappings
    declare -A common_pkg_map=(
        ["x11"]="termux-x11-nightly aterm xorg-twm fluxbox openbox obconf-qt feh xorg-xsetroot xdotool wmctrl xfce4 xfce4-terminal xfce4-goodies lxqt qterminal mate-desktop mate-terminal zenity"
        ["glibc"]="glibc"
        ["tur"]="gcc-12 llvm"
        ["root"]="tsu"
    )

    # Package manager specific configurations
    if [ "$pkg_manager" = "pkg" ]; then
        # Termux (pkg) specific mappings
        declare -A repo_pkg_map=(
            ["x11-repo"]="x11-repo ${common_pkg_map[x11]}"
            ["glibc-repo"]="glibc-repo ${common_pkg_map[glibc]}"
            ["tur-repo"]="tur-repo ${common_pkg_map[tur]}"
            ["root-repo"]="root-repo ${common_pkg_map[root]}"
        )
        declare -A pattern_repo_map=(
            ["*x11*"]="x11-repo"
            ["*glibc*"]="glibc-repo"
            ["*tur*"]="tur-repo"
            ["*root*"]="root-repo"
        )
    else
        # Termux-pacman specific mappings
        declare -A repo_pkg_map=(
            ["x11"]="${common_pkg_map[x11]}"
            ["gpkg"]="${common_pkg_map[glibc]}"  # Changed from glibc to gpkg
            ["tur"]="${common_pkg_map[tur]}"
            ["root"]="${common_pkg_map[root]}"
        )
        declare -A pattern_repo_map=(
            ["*x11*"]="x11"
            ["*glibc*"]="gpkg"  # Changed from glibc to gpkg
            ["*tur*"]="tur"
            ["*root*"]="root"
        )
        local pacman_conf="$PREFIX/etc/pacman.conf"
        local repo_url="https://service.termux-pacman.dev"
    fi

    local to_install=()
    local repos_to_enable=()

    # First check all packages
    for pkg in "$@"; do
        if [ "$pkg_manager" = "pkg" ]; then
            if ! pkg list-installed | grep -qw "^$pkg$"; then
                to_install+=("$pkg")
            else
                echo "$pkg is already installed"
                continue
            fi
        else
            if ! pacman -Qi "$pkg" &>/dev/null 2>&1; then
                to_install+=("$pkg")
            else
                echo "$pkg is already installed"
                continue
            fi
        fi

        # Check if package exists in any repo's package list
        for repo in "${!repo_pkg_map[@]}"; do
            if [[ " ${repo_pkg_map[$repo]} " == *" $pkg "* ]]; then
                repos_to_enable+=("$repo")
            fi
        done
        
        # Check pattern matching if no direct match found
        if [[ ${#repos_to_enable[@]} -eq 0 ]]; then
            for pattern in "${!pattern_repo_map[@]}"; do
                if [[ "$pkg" == $pattern ]]; then
                    repos_to_enable+=("${pattern_repo_map[$pattern]}")
                fi
            done
        fi
    done

    [[ ${#to_install[@]} -eq 0 ]] && return 0

    # Enable required repos if needed (remove duplicates)
    local unique_repos=()
    readarray -t unique_repos < <(printf '%s\n' "${repos_to_enable[@]}" | sort -u)

    # Handle repository enabling based on package manager
    for repo in "${unique_repos[@]}"; do
        if [ "$pkg_manager" = "pkg" ]; then
            if ! pkg repo | grep -q "$repo"; then
                echo "Enabling $repo..."
                pkg install -y "$repo" || {
                    echo "Failed to install $repo" >&2
                    return 1
                }
            fi
        else
            if ! grep -q "^\[$repo\]" "$pacman_conf" 2>/dev/null; then
                echo "Enabling $repo repository..."
                # Create backup of pacman.conf
                cp "$pacman_conf" "${pacman_conf}.bak" 2>/dev/null
                # Add repository configuration
                sed -i "/^\[core\]/i \[$repo\]\nServer = ${repo_url}/$repo/\$arch\n" "$pacman_conf" || {
                    echo "Failed to enable $repo repository" >&2
                    # Restore backup if modification failed
                    mv "${pacman_conf}.bak" "$pacman_conf" 2>/dev/null
                    return 1
                }
                echo "Successfully enabled $repo repository"
            fi
        fi
    done

    # Update package list if we added any repos
    if [[ ${#unique_repos[@]} -gt 0 ]]; then
        if [ "$pkg_manager" = "pkg" ]; then
            echo "Updating package lists..."
            pkg update -y || {
                echo "Failed to update packages" >&2
                return 1
            }
        else
            echo "Synchronizing package databases..."
            pacman -Sy || {
                echo "Failed to update package databases" >&2
                return 1
            }
        fi
    fi

    # Install missing packages
    echo "Installing packages: ${to_install[*]}..."
    if [ "$pkg_manager" = "pkg" ]; then
        pkg install -y "${to_install[@]}" || {
            echo "Failed to install packages" >&2
            return 1
        }
    else
        pacman -S --noconfirm "${to_install[@]}" || {
            echo "Failed to install packages" >&2
            return 1
        }
    fi
    
    echo "Package installation completed successfully"
    return 0
}
install_termux_x11() {
    # install Termux-X11 APK
    local error arch TARGET_ARCH API_URL APK_URL FILENAME
    
    error=$(cd /data/data/com.termux.x11 2>&1 >/dev/null)
    if [[ $error == *"No such file or directory"* ]]; then
        arch=$(uname -m)
        case "$arch" in
            "aarch64"|"arm64") TARGET_ARCH="arm64-v8a" ;;
            "armv7l"|"armhf") TARGET_ARCH="armeabi-v7a" ;;
            "i386"|"i686")    TARGET_ARCH="x86" ;;
            "x86_64")         TARGET_ARCH="x86_64" ;;
            *)
                echo "Unsupported architecture: $arch"
                return 1
                ;;
        esac
        # Get latest release URL
        API_URL="https://api.github.com/repos/termux/termux-x11/releases/latest"
        APK_URL=$(curl -s "$API_URL" | grep -o "https://.*app-${TARGET_ARCH}-debug.apk")
        if [ -z "$APK_URL" ]; then
            echo "Error: APK not found for $TARGET_ARCH"
            return 1
        fi
        FILENAME="termux-x11-${TARGET_ARCH}-debug.apk"
        wget "$APK_URL" -O "$FILENAME"
        termux-open "$FILENAME" # Opens in Termux package installer
    fi
}
set_or_update_bashrc_variable() {
    # Check if exactly 2 arguments are provided
    if [ "$#" -ne 2 ]; then
        >&2 echo "Usage: set_or_update_bashrc_variable <VARIABLE_NAME> <VALUE>"
        return 1
    fi

    local var_name="$1"
    local value="$2"
    local bashrc_file="$HOME/.bashrc"
    local temp_file="${bashrc_file}.tmp"

    # Check if the variable exists in .bashrc
    if grep -q "^export ${var_name}=" "$bashrc_file"; then
        # Variable exists, update its value using awk
        awk -v var="^export ${var_name}=" -v newval="export ${var_name}='${value}'" \
            '{if ($0 ~ var) print newval; else print $0}' "$bashrc_file" > "$temp_file" && mv "$temp_file" "$bashrc_file"
    else
        # Variable doesn't exist, add it
        echo "export ${var_name}='${value}'" >> "$bashrc_file"
    fi

    # Source the updated .bashrc to make changes take effect in current session
    source "$bashrc_file" >/dev/null 2>&1
}
set_or_update_bashrc_alias() {
    if [ $# -ne 2 ]; then
        echo "Usage: set_or_update_bashrc_alias <alias_name> <alias_command>"
        return 1
    fi

    local alias_name="$1"
    local alias_command="$2"
    local bashrc_file="$HOME/.bashrc"
    local temp_file="$(mktemp)"
    local alias_line="alias $alias_name='$alias_command'"
    local found=false

    # Create .bashrc if it doesn't exist
    [ -f "$bashrc_file" ] || touch "$bashrc_file"

    # Process the file
    while IFS= read -r line; do
        if [[ "$line" == "alias $alias_name="* ]]; then
            echo "$alias_line"  # Replace existing alias
            found=true
        else
            echo "$line"  # Keep other lines unchanged
        fi
    done < "$bashrc_file" > "$temp_file"

    # If alias wasn't found, append it
    if [ "$found" = false ]; then
        echo "$alias_line" >> "$temp_file"
    fi

    # Replace the original file
    mv "$temp_file" "$bashrc_file"

    # Source the updated file
    source "$bashrc_file"
}
set_termux_properties() {
    # Argument check (supports both quoted and unquoted)
    if [[ $# -ne 2 ]]; then
        echo "Usage: set_termux_properties <key> <value>" >&2
        echo "       set_termux_properties \"<key>\" \"<value>\"" >&2
        echo "       set_termux_properties \"<key>\" \"\"   # To comment out key" >&2
        return 1
    fi

    local KEY="${1//\"/}"  # Remove any surrounding quotes
    local VALUE="${2//\"/}" # Remove any surrounding quotes
    local PROPERTIES_FILE="$HOME/.termux/termux.properties"
    
    # Silent directory and file creation
    mkdir -p $HOME/.termux 2>/dev/null || return 1
    touch "$PROPERTIES_FILE" 2>/dev/null || return 1

    # Handle empty value (comment out the key)
    if [[ -z "$VALUE" ]]; then
        if grep -q -E "^(#\s*)?${KEY}\s*[=:]" "$PROPERTIES_FILE" 2>/dev/null; then
            # Comment out existing entry
            sed -i -E "/^(#\s*)?${KEY}\s*[=:]/s/^/# /" "$PROPERTIES_FILE" 2>/dev/null || return 1
        else
            # Add new commented entry
            echo "# ${KEY}=" >> "$PROPERTIES_FILE" 2>/dev/null || return 1
        fi
    else
        # Update or add property (handles all formats)
        if grep -q -E "^(#\s*)?${KEY}\s*[=:]" "$PROPERTIES_FILE" 2>/dev/null; then
            sed -i -E "/^(#\s*)?${KEY}\s*[=:]/c\\${KEY}=${VALUE}" "$PROPERTIES_FILE" 2>/dev/null || return 1
        else
            echo "${KEY}=${VALUE}" >> "$PROPERTIES_FILE" 2>/dev/null || return 1
        fi
    fi

    # Only show errors if reload fails
    termux-reload-settings 2>/dev/null || {
        echo "Error: Failed to reload Termux settings" >&2
        return 2
    }
    : '
    usage example:
    set_termux_properties bell-character beep     # Set property
    set_termux_properties "bell-character" "beep" # Same with quotes
    set_termux_properties bell-character ""       # Comment out property
    '
}
download_bootstrap() {
  if [ -n "$latest_url" ]; then
    echo "Downloading bootstrap..."
    curl -C - -L -O "$latest_url"
    if [ $? -ne 0 ]; then
      echo "Download failed. Exiting."
      exit 1
    fi
    echo "Download complete."
  else
    echo "Failed to find valid URL for selected package manager. Exiting."
    exit 1
  fi
}
unzip_bootstrap() {
  mkdir -p /data/data/com.termux/files/usr-n
  mv bootstrap-${arch}.zip /data/data/com.termux/files/usr-n
  unzip /data/data/com.termux/files/usr-n/bootstrap-${arch}.zip -d /data/data/com.termux/files/usr-n
  rm /data/data/com.termux/files/usr-n/bootstrap-${arch}.zip
  cd /data/data/com.termux/files/usr-n
  cat SYMLINKS.txt | awk -F "←" '{system("ln -s '"'"'"$1"'"'"' '"'"'"$2"'"'"'")}'
  cd
}
switchpkgmanager() {
rm -fr $PREFIX
/system/bin/mv /data/data/com.termux/files/usr-n/ /data/data/com.termux/files/usr/
/system/bin/echo "switch pkg manager complete"
/system/bin/echo "will close in 5 seconds. reopen termux to finish setup." && /system/bin/sleep 5
exit
}
arch=$(uname -m)
while true; do
    clear
    echo "Termux Environment Manager"
    echo "select a choice:"
    echo "1) Restore Termux backup"
    echo "2) Backup Termux"
    echo "3) switch package manager in termux"
    echo "4) Setup Termux GUI"
    echo "5) Setup Build Environment"
    echo "6) Add Repositories to Termux"
    echo "7) Exit"
    read -p "Enter number of choice: " choice
    case $choice in
        1)
            check_storage
            tar --exclude='.cache' -zxf /sdcard/termux-backup.tar.gz -C /data/data/com.termux/files --recursive-unlink --preserve-permissions
            echo "termux restore complete"
            echo "will close in 5 seconds. reopen termux to finish setup." && sleep 5
            exit
            ;;
        2)
            check_storage
            tar --exclude='.cache' -zcf /sdcard/termux-backup.tar.gz -C /data/data/com.termux/files ./home ./usr
            echo "termux backup complete"
            read -p "Press Enter to return to main menu"
            ;;
        3)
            echo "Switch to what package manager:"
            echo "Choose option:"
            echo "1) apt based bootstrap"
            echo "2) pacman based bootstrap"
            read -p "Enter number of option: " option
            case $option in
                1)
                    install_if_missing jq
                    latest_url=$(curl -s https://api.github.com/repos/termux/termux-packages/releases/latest | jq -r ".assets[] | select(.name | test(\"bootstrap-${arch}.*\\\\.zip\")) | .browser_download_url")
                    download_bootstrap
                    unzip_bootstrap
                    switchpkgmanager
                    ;;
                2)
                    install_if_missing jq
                    latest_url=$(curl -s https://api.github.com/repos/termux-pacman/termux-packages/releases/latest | jq -r ".assets[] | select(.name | test(\"bootstrap-${arch}.*\\\\.zip\")) | .browser_download_url")
                    download_bootstrap
                    unzip_bootstrap
                    switchpkgmanager
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
            read -p "Press Enter to return to main menu"
            ;;
        4)  
            check_storage
            install_if_missing curl wget termux-x11-nightly
            install_termux_x11
            echo "Termux GUI Setup"
            echo "Choose option:"
            echo "1) Window Manager (Fluxbox or Openbox)"
            echo "2) Desktop environment (XFCE, LXQt or MATE)"
            echo "3) Install zenity,python-tkinter & pysimplegui"
            read -p "Enter number of option: " option
            case $option in
                1)
                    echo "Choose Window Manager:"
                    echo "1) Fluxbox (Lightweight, fast)"
                    echo "2) Openbox (Highly customizable)"
                    read -p "Enter your choice: " wm_choice
                    case $wm_choice in
                        1)
                            install_if_missing fluxbox aterm
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "fluxbox & aterm"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            set_termux_properties "fullscreen" "true"
                            if [ ! -f $HOME/.fluxbox/menu ]; then
                                fluxbox-generate_menu
                            fi
                            echo "Fluxbox installed. Run 'startx11' to start."
                            read -p "Press Enter to start Fluxbox Window Manager"
                            termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
                            ;;
                        2)
                            install_if_missing openbox obconf-qt feh xorg-xsetroot aterm
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "openbox-session"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 -dpi 160 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            set_termux_properties "fullscreen" "true"
                            mkdir -p $HOME/.config/openbox
                            cp -n $PREFIX/etc/xdg/openbox/* $HOME/.config/openbox/
                            chmod +x $HOME/.config/openbox/autostart
                            AUTOSTART_LINES=(
                                "# start aterm terminal"
                                "aterm -fg white -bg black -sh 60 +sb -tn xterm-256color &"
                                ""
                                "# set backgroud color"
                                "xsetroot -solid black &"
                            )
                            if [ ! -f "$HOME/.config/openbox/autostart" ] || ! grep -q "xsetroot -solid black" "$HOME/.config/openbox/autostart"; then
                                # Add the lines to the file
                                printf "%s\n" "${AUTOSTART_LINES[@]}" >> "$HOME/.config/openbox/autostart"
                                echo "Added lines to $HOME/.config/openbox/autostart"
                            fi
                            file="$HOME/.config/openbox/rc.xml"
                            if ! grep -qzP '\n\s*<application class="\*" name="\*" title="\*">\n\s*<maximized>yes</maximized>\n\s*</application>' "$file"; then
                                sed -i -E '/^[[:space:]]*<applications>$/ {
                                    p
                                    s/<applications>/<application class="*" name="*" title="*">/
                                    p
                                    s/<application.*/<maximized>yes<\/maximized>/
                                    p
                                    s/<maximized.*/<\/application>/
                                }' "$file"
                                echo "openbox rule added to rc.xml"
                            fi
                            echo "Openbox installed. Run 'startx11' to start."
                            read -p "Press Enter to start Openbox Window Manager"
                            termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
                            ;;
                        *)
                            echo "Invalid choice. Returning to main menu."
                            ;;
                    esac
                    ;;
                2)
                    echo "Choose Desktop Environment:"
                    echo "1) XFCE (Lightweight, traditional)"
                    echo "2) LXQt (Fast, Qt-based)"
                    echo "3) MATE (GNOME 2 fork, classic)"
                    read -p "Enter your choice: " de_choice
                    case $de_choice in
                        1) # XFCE
                            install_if_missing xfce4 xfce4-terminal xfce4-goodies
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "startxfce4"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            set_termux_properties "fullscreen" "true"
                            echo "XFCE installed. Run 'startx11' to start."
                            read -p "Press Enter to start XFCE"
                            termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
                            ;;
                        2) # LXQt
                            install_if_missing lxqt qterminal
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "startlxqt"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            set_termux_properties "fullscreen" "true"
                            echo "LXQt installed. Run 'startx11' to start."
                            read -p "Press Enter to start LXQt"
                            termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
                            ;;
                        3) # MATE
                            install_if_missing mate-desktop mate-terminal
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "mate-session"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            set_termux_properties "fullscreen" "true"
                            echo "MATE installed. Run 'startx11' to start."
                            read -p "Press Enter to start MATE"
                            termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity
                            ;;
                    esac
                    ;;
                3)
                    install_if_missing abseil-cpp adwaita-icon-theme adwaita-icon-theme-legacy appstream aspell at-spi2-core abseil-cpp brotli clang dbus desktop-file-utils enchant fontconfig freetype fribidi game-music-emu gdbm gdk-pixbuf giflib glib glib-networking graphene gst-plugins-bad gst-plugins-base gst-plugins-good gstreamer gtk-update-icon-cache gtk3 gtk4 harfbuzz harfbuzz-icu hicolor-icon-theme hunspell hunspell-en-us imlib2 iso-codes libadwaita libandroid-execinfo libandroid-posix-semaphore libandroid-shmem libaom libass libcaca libcairo libcompiler-rt libcrypt libdav1d libde265 libdrm libepoxy libexpat libffi libflac libglvnd libgraphite libheif libhyphen libice libicu libid3tag libjpeg-turbo libjxl libllvm libltdl liblzo libmp3lame libogg libopus libpixman libpng libpsl librav1e librsvg libsm libsndfile libsoup3 libsoxr libsqlite libsrt libstemmer libtasn1 libtheora libtiff libuuid libvorbis libvpx libwayland libwebp libwebrtc-audio-processing libx11 libx265 libxau libxcb libxcomposite libxcursor libxdamage libxdmcp libxext libxfixes libxft libxi libxinerama libxkbcommon libxml2 libxmlb libxmu libxrandr libxrender libxshmfence libxslt libxss libxt libxtst libxv libxxf86vm libyaml littlecms lld llvm make mesa mesa-vulkan-icd-swrast mpg123 ncurses ncurses-ui-libs ndk-sysroot openal-soft opengl openh264 openjpeg pango pkg-config pulseaudio python python-ensurepip-wheels python-pip python-tkinter shared-mime-info speexdsp tcl tk ttf-dejavu vulkan-icd vulkan-loader vulkan-loader-generic webkitgtk-6.0 woff2 xkeyboard-config xorg-xauth zenity
                    pip install pysimplegui
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
            read -p "Press Enter to return to main menu"
            ;;
        5)
            install_if_missing proot-distro ldd liblzma openssl which tree mtd-utils lzop sleuthkit cabextract p7zip lhasa arj cmake rust git wget nodejs autoconf automake python-pip python-pillow python-scipy ninja patchelf binutils bison flex build-essential
            npm install -g degit
            [ ! -f "$HOME/.bashrc" ] && touch "$HOME/.bashrc"
            cat <<'EOF' >> "$HOME/.bashrc"
export PATH="$PATH:$HOME/.cargo/bin:/system/bin"
export CFLAGS="-Wno-deprecated-declarations -Wno-unreachable-code"
export LD_LIBRARY_PATH="$PREFIX/lib"            
export AR="llvm-ar"
if [ "$(uname -m)" = "x86_64" ] || [ "$(uname -m)" = "aarch64" ]; then
export LDFLAGS="-L/system/lib64"            
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/system/lib64"
else
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/system/lib"
fi
EOF
            source "$HOME/.bashrc"
            echo "Environment setup complete"
            read -p "Press Enter to return to main menu"
            ;;
        6)
            echo "What repositories to add? (separate choices with comma)"
            echo "1) termux user repository (tur)"
            echo "2) gnu c library repository (glibc)"
            echo "3) x11 windowing system repository"
            echo "4) root user repository"
            read -p "Enter your choices (e.g., 1,2,3): " choices
            IFS=',' read -ra selected <<< "$choices"
            repos=""
            for choice in "${selected[@]}"; do
                case $choice in
                    1)
                        repos+=" tur-repo"
                        ;;
                    2)
                        repos+=" glibc-repo"
                        ;;
                    3)
                        repos+=" x11-repo"
                        ;;
                    4)
                        repos+=" root-repo"
                        ;;
                    *)
                        echo "Invalid option: $choice. Skipping."
                        ;;
                esac
            done
            if [ -n "$repos" ]; then
                install_repos
                echo "Repositories added successfully"
            else
                echo "No valid repositories selected."
            fi
            read -p "Press Enter to return to main menu"
            ;;
        7)
            echo "Exiting script."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            read -p "Press Enter to continue"
            ;;
    esac
done

: '
$PREFIX=/data/data/com.termux/files/usr
$HOME=/data/data/com.termux/files/home

pacman uses:
$PREFIX/etc/pacman.d/
$PREFIX/etc/pacman.conf

apt uses:
$PREFIX/etc/apt/sources.list.d/
$PREFIX/etc/apt/sources.list

Termux X-server add-on:
https://github.com/termux/termux-x11

termux-x11 touchpad emulation gestures:
Tap for click
Double tap for double click
Two-finger tap for right click
Three-finger tap for middle click
Two-finger vertical swipe for vertical scroll
Two-finger horizontal swipe for horizontal scroll
Three-finger swipe down to show-hide additional keys bar.

termux-x11 touchscreen mode gestures:
Single tap for left button click.
Long tap for mouse holding.
Double tap for double click
Two-finger tap for right click
Three-finger tap for middle click
Two-finger vertical swipe for vertical scroll
Two-finger horizontal swipe for horizontal scroll
Three-finger swipe down to show-hide additional keys bar.

Remote Access - Termux Wiki
https://wiki.termux.com/wiki/Remote_Access

Bypassing NAT - Termux Wiki
https://wiki.termux.com/wiki/Bypassing_NAT

Termux-services - Termux Wiki
https://wiki.termux.com/wiki/Termux-services

Termux:Boot - Termux Wiki
https://wiki.termux.com/wiki/Termux:Boot

Development
https://wiki.termux.com/wiki/Development

Development Environments
https://wiki.termux.com/wiki/Development_Environments

Differences from Linux
https://wiki.termux.com/wiki/Differences_from_Linux

# use Linux file system layout
termux-chroot

Package Management
https://wiki.termux.com/wiki/Package_Management

Glibc packages for termux
https://github.com/termux/glibc-packages

Termux User Repository (TUR)
https://github.com/termux-user-repository/tur

termux-pacman service repositories
https://service.termux-pacman.dev/

AUR - Termux Wiki
https://wiki.termux.com/wiki/AUR

archiconda3: Light-weight Anaconda environment (ARM64)
https://github.com/piyoki/archiconda3

# build & install binwalk in termux
npx degit github:ReFirmLabs/binwalk binwalk --force
cd binwalk
cargo build --release
cargo install --path .
cd .. && rm -rf binwalk/
binwalk --version
'
