#!/bin/bash

check_storage() {
  if [ ! -d ~/storage ]; then
    termux-setup-storage
  fi
}
check_jq() {
  if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Installing now..."
    if pkg update -y && pkg install -y jq; then
      echo "jq installed successfully."
    else
      echo "Failed to install jq. check package manager or network connection."
      exit 1
    fi
  else
    echo "jq is already installed."
  fi
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
    echo "4) Setup Build Environment"
    echo "5) Add Repositories to Termux"
    echo "6) Exit"
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
                check_jq
                latest_url=$(curl -s https://api.github.com/repos/termux/termux-packages/releases/latest | jq -r ".assets[] | select(.name | test(\"bootstrap-${arch}.*\\\\.zip\")) | .browser_download_url")
                download_bootstrap
                unzip_bootstrap
                switchpkgmanager
                ;;
                2)
                check_jq
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
            pkg update -y
            pkg install proot-distro ldd liblzma openssl which tree mtd-utils lzop sleuthkit cabextract p7zip lhasa arj cmake rust git wget nodejs autoconf automake python-pip python-pillow python-scipy ninja patchelf binutils bison flex build-essential -y
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
        5)
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
                pkg install $repos -y
                echo "Repositories added successfully"
            else
                echo "No valid repositories selected."
            fi
            read -p "Press Enter to return to main menu"
            ;;
        6)
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
# Development
# https://wiki.termux.com/wiki/Development

# Development Environments
# https://wiki.termux.com/wiki/Development_Environments

# Differences from Linux
# https://wiki.termux.com/wiki/Differences_from_Linux
# use Linux file system layout
termux-chroot

# Package Management
# https://wiki.termux.com/wiki/Package_Management

# Glibc packages for termux
# https://github.com/termux/glibc-packages

# Termux User Repository (TUR)
# https://github.com/termux-user-repository/tur

# Remote Access - Termux Wiki
# https://wiki.termux.com/wiki/Remote_Access

# Bypassing NAT - Termux Wiki
# https://wiki.termux.com/wiki/Bypassing_NAT

# Termux-services - Termux Wiki
# https://wiki.termux.com/wiki/Termux-services

# Termux:Boot - Termux Wiki
# https://wiki.termux.com/wiki/Termux:Boot

$PREFIX=/data/data/com.termux/files/usr
$HOME=/data/data/com.termux/files/home

# archiconda3: Light-weight Anaconda environment (ARM64)
# https://github.com/piyoki/archiconda3

# build & install binwalk in termux
npx degit github:ReFirmLabs/binwalk binwalk --force
cd binwalk
cargo build --release
cargo install --path .
cd .. && rm -rf binwalk/
binwalk --version
'
