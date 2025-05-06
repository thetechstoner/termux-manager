#!/bin/bash
check_storage() {
  if [ ! -d ~/storage ]; then
    termux-setup-storage
  fi
}
install_repos() {
    # Check for tur-repo
    [[ " ${repos} " == *" tur-repo "* ]] && {
        # Commands to run for tur-repo
        if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
          pkg install -y tur-repo
        fi
    }
    # Check for glibc-repo
    [[ " ${repos} " == *" glibc-repo "* ]] && {
        # Commands to run for glibc-repo
        if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
          pkg install -y glibc-repo
        fi
    }
    # Check for x11-repo
    [[ " ${repos} " == *" x11-repo "* ]] && {
        # Commands to run for x11-repo
        if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
          pkg install -y x11-repo
        fi
    }
    # Check for root-repo
    [[ " ${repos} " == *" root-repo "* ]] && {
        # Commands to run for root-repo
        if [ -d "$PREFIX/etc/apt/sources.list.d/" ]; then
          pkg install -y root-repo
        fi
    }
    return 0
}
install_if_missing() {
    # Repository to packages mapping (multi-package format)
    declare -A repo_pkg_map=(
        # X11 repository
        ["x11-repo"]="x11-repo termux-x11-nightly aterm xorg-twm fluxbox openbox obconf-qt xfce4 xfce4-terminal xfce4-goodies lxqt qterminal mate-desktop mate-terminal"
        
        # glibc repository
        ["glibc-repo"]="glibc-repo"
        
        # termux user repository
        ["tur-repo"]="tur-repo gcc-12 llvm"
        
        # rooted device repository
        ["root-repo"]="root-repo tsu"
        
    )

    # Additional patterns that require specific repos
    declare -A pattern_repo_map=(
        ["*x11*"]="x11-repo"
        ["*glibc*"]="glibc-repo"
        ["*tur*"]="tur-repo"
        ["*root*"]="root-repo"
    )

    local to_install=()
    local repos_to_enable=()

    # First check all packages
    for pkg in "$@"; do
        if ! pkg list-installed | grep -qw "^$pkg$"; then
            to_install+=("$pkg")
            
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
            
            # Check package metadata as last resort
            if [[ ${#repos_to_enable[@]} -eq 0 ]]; then
                pkg_show_output=$(pkg show "$pkg" 2>/dev/null)
                for repo in "${!repo_pkg_map[@]}"; do
                    if [[ "$pkg_show_output" == *"$repo"* ]]; then
                        repos_to_enable+=("$repo")
                    fi
                done
            fi
        else
            echo "$pkg is already installed"
        fi
    done

    [[ ${#to_install[@]} -eq 0 ]] && return 0

    # Enable required repos if needed (remove duplicates)
    local unique_repos=()
    readarray -t unique_repos < <(printf '%s\n' "${repos_to_enable[@]}" | sort -u)

    for repo in "${unique_repos[@]}"; do
        if ! pkg repo | grep -q "$repo"; then
            echo "Enabling $repo..."
            pkg install -y "$repo" || {
                echo "Failed to install $repo" >&2
                return 1
            }
        fi
    done

    # Update package list if we added any repos
    [[ ${#unique_repos[@]} -gt 0 ]] && {
        pkg update || {
            echo "Failed to update packages" >&2
            return 1
        }
    }

    # Install missing packages
    echo "Installing packages: ${to_install[*]}..."
    pkg install -y "${to_install[@]}" || {
        echo "Failed to install packages" >&2
        return 1
    }
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
        # Variable exists, update its value
        sed "s/^export ${var_name}=.*/export ${var_name}='${value}'/" "$bashrc_file" > "$temp_file" && mv "$temp_file" "$bashrc_file"
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
rm -fr /data/data/com.termux/files/usr/
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
            tar -zxf /sdcard/termux-backup.tar.gz -C /data/data/com.termux/files --recursive-unlink --preserve-permissions
            echo "termux restore complete"
            echo "will close in 5 seconds. reopen termux to finish setup." && sleep 5
            exit
            ;;
        2)
            check_storage
            tar -zcf /sdcard/termux-backup.tar.gz -C /data/data/com.termux/files ./home ./usr
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
            echo "1) Tab Window Manager (xorg-twm)"
            echo "2) Window Manager (Fluxbox or Openbox)"
            echo "3) Desktop environment (XFCE, LXQt or MATE)"
            read -p "Enter number of option: " option
            case $option in
                1)
                    install_if_missing xorg-twm aterm
                    set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "twm & aterm"
                    set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                    echo "Tab Window Manager installed. Run 'startx11' to start."
                    read -p "Press Enter to start Tab Window Manager"
                    startx11
                    ;;
                2)
                    echo "Choose Window Manager:"
                    echo "1) Fluxbox (Lightweight, fast)"
                    echo "2) Openbox (Highly customizable)"
                    read -p "Enter your choice: " wm_choice
                    case $wm_choice in
                        1)
                            install_if_missing fluxbox aterm
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "fluxbox & aterm"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            echo "Fluxbox installed. Run 'startx11' to start."
                            read -p "Press Enter to start Fluxbox Window Manager"
                            startx11
                            ;;
                        2)
                            install_if_missing openbox aterm obconf-qt
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "openbox-session & aterm"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            echo "Openbox installed. Run 'startx11' to start."
                            read -p "Press Enter to start Openbox Window Manager"
                            startx11
                            ;;
                        *)
                            echo "Invalid choice. Returning to main menu."
                            ;;
                    esac
                    ;;
                3)
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
                            echo "XFCE installed. Run 'startx11' to start."
                            read -p "Press Enter to start XFCE"
                            startx11
                            ;;
                        2) # LXQt
                            install_if_missing lxqt qterminal
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "startlxqt"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            echo "LXQt installed. Run 'startx11' to start."
                            read -p "Press Enter to start LXQt"
                            startx11
                            ;;
                        3) # MATE
                            install_if_missing mate-desktop mate-terminal
                            set_or_update_bashrc_variable "TERMUX_X11_XSTARTUP" "mate-session"
                            set_or_update_bashrc_alias "startx11" "termux-x11 :1 & sleep 2 && am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity"
                            echo "MATE installed. Run 'startx11' to start."
                            read -p "Press Enter to start MATE"
                            startx11
                            ;;
                    esac
                    ;;
                *)
                    echo "Invalid option"
                    ;;
            esac
            read -p "Press Enter to return to main menu"
            ;;
        5)
            pkg update -y
            install_if_missing proot-distro ldd liblzma openssl which tree mtd-utils lzop sleuthkit cabextract p7zip lhasa arj cmake rust git wget nodejs autoconf automake python-pip python-pillow python-scipy ninja patchelf binutils bison flex build-essential
            npm install -g degit
            [ ! -f ~/.bashrc ] && touch ~/.bashrc
            echo 'export PATH="$PATH:~/.cargo/bin:/system/bin"
            export CFLAGS="-Wno-deprecated-declarations -Wno-unreachable-code"
            export LD_LIBRARY_PATH="/data/data/com.termux/files/usr/lib"
            AR="llvm-ar"
            if [ "$(uname -m)" == "x86_64" ] || [ "$(uname -m)" == "aarch64" ]; then
            export LDFLAGS="-L/system/lib64"
            export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/system/lib64"
            else
            export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/system/lib"
            fi
            # Linux file system layout
            termux-chroot' >> ~/.bashrc
            source ~/.bashrc
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
# $PREFIX=/data/data/com.termux/files/usr
# $HOME=/data/data/com.termux/files/home

pacman uses:
# $PREFIX/etc/pacman.d/
apt uses:
# $PREFIX/etc/apt/sources.list.d/

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

Remote Access - Termux Wiki
https://wiki.termux.com/wiki/Remote_Access

Bypassing NAT - Termux Wiki
https://wiki.termux.com/wiki/Bypassing_NAT

Termux-services - Termux Wiki
https://wiki.termux.com/wiki/Termux-services

Termux:Boot - Termux Wiki
https://wiki.termux.com/wiki/Termux:Boot

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
