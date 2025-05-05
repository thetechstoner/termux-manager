#!/bin/bash
check_storage() {
  if [ ! -d ~/storage ]; then
    termux-setup-storage
  fi
}
install_if_missing() {
    # Enable x11-repo if any package requires it
    local enable_x11=false
    local to_install=()
    
    # First check all packages
    for pkg in "$@"; do
        if ! pkg list-installed | grep -qw "^$pkg$"; then
            to_install+=("$pkg")
            if [[ "$pkg" == *"x11"* ]] || (pkg show "$pkg" 2>/dev/null | grep -q "x11-repo"); then
                enable_x11=true
            fi
        else
            echo "$pkg is already installed"
        fi
    done
    
    [[ ${#to_install[@]} -eq 0 ]] && return 0
    
    # Enable x11-repo if needed
    if $enable_x11 && ! pkg repo | grep -q "x11-repo"; then
        echo "Enabling x11-repo..."
        pkg install -y x11-repo || {
            echo "Failed to install x11-repo" >&2
            return 1
        }
        pkg update || {
            echo "Failed to update packages" >&2
            return 1
        }
    fi
    
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
set_or_update_bashrc_var() {
    local var_name="$1"
    local var_value="$2"
    local bashrc_file="$HOME/.bashrc"
    local export_line="export $var_name=\"$var_value\""

    # Check if the variable is already defined in ~/.bashrc
    if grep -q "^export $var_name=" "$bashrc_file"; then
        # Update existing variable
        sed -i "s|^export $var_name=.*|$export_line|" "$bashrc_file"
        echo "Updated $var_name in $bashrc_file"
    else
        # Append new variable
        echo "$export_line" >> "$bashrc_file"
        echo "Added $var_name to $bashrc_file"
    fi

    # apply changes immediately
    source "$bashrc_file"
}
install_repos() {
    # Check for tur-repo
    [[ " ${repos} " == *" tur-repo "* ]] && {
        # Commands to run for tur-repo
        if [ -f "$PREFIX/etc/pacman.conf" ]; then
        # pacman.conf exists
        else
        pkg install -y tur-repo
        fi
    }
    # Check for glibc-repo
    [[ " ${repos} " == *" glibc-repo "* ]] && {
        # Commands to run for glibc-repo
        if [ -f "$PREFIX/etc/pacman.conf" ]; then
        # pacman.conf exists
        else
        pkg install -y glibc-repo
        fi
    }
    # Check for x11-repo
    [[ " ${repos} " == *" x11-repo "* ]] && {
        # Commands to run for x11-repo
        if [ -f "$PREFIX/etc/pacman.conf" ]; then
        # pacman.conf exists
        else
        pkg install -y x11-repo
        fi
    }
    # Check for root-repo
    [[ " ${repos} " == *" root-repo "* ]] && {
        # Commands to run for root-repo
        if [ -f "$PREFIX/etc/pacman.conf" ]; then
        # pacman.conf exists
        else
        pkg install -y root-repo
        fi
    }
    return 0
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
                    set_or_update_bashrc_var "TERMUX_X11_XSTARTUP" "twm & aterm"
                    echo "Tab Window Manager installed. Run 'termux-x11 :1' to start."
                    read -p "Press Enter to start Tab Window Manager"
                    termux-x11 :1
                    ;;
                2)
                    echo "Choose Window Manager:"
                    echo "1) Fluxbox (Lightweight, fast)"
                    echo "2) Openbox (Highly customizable)"
                    read -p "Enter your choice: " wm_choice
                    case $wm_choice in
                        1)
                            install_if_missing fluxbox aterm
                            set_or_update_bashrc_var "TERMUX_X11_XSTARTUP" "fluxbox & aterm"
                            echo "Fluxbox installed. Run 'termux-x11 :1' to start."
                            read -p "Press Enter to start Fluxbox Window Manager"
                            termux-x11 :1
                            ;;
                        2)
                            install_if_missing openbox aterm obconf
                            set_or_update_bashrc_var "TERMUX_X11_XSTARTUP" "openbox-session & aterm"
                            echo "Openbox installed. Run 'termux-x11 :1' to start."
                            read -p "Press Enter to start Openbox Window Manager"
                            termux-x11 :1
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
                            set_or_update_bashrc_var "TERMUX_X11_XSTARTUP" "startxfce4"
                            echo "XFCE installed. Run 'termux-x11 :1' to start."
                            read -p "Press Enter to start XFCE"
                            termux-x11 :1
                            ;;
                        2) # LXQt
                            install_if_missing lxqt qterminal
                            set_or_update_bashrc_var "TERMUX_X11_XSTARTUP" "startlxqt"
                            echo "LXQt installed. Run 'termux-x11 :1' to start."
                            read -p "Press Enter to start LXQt"
                            termux-x11 :1
                            ;;
                        3) # MATE
                            install_if_missing mate-desktop mate-terminal
                            set_or_update_bashrc_var "TERMUX_X11_XSTARTUP" "mate-session"
                            echo "MATE installed. Run 'termux-x11 :1' to start."
                            read -p "Press Enter to start MATE"
                            termux-x11 :1
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
$PREFIX=/data/data/com.termux/files/usr
$HOME=/data/data/com.termux/files/home

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
