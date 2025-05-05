# Termux Environment Manager

A powerful Bash script to manage Termux environments, package managers, backups, and development setups.

## Features

- 🔄 Switch between **apt** and **pacman** package managers
- 💾 Backup & restore Termux environments
- 🛠️ Setup complete development environment
- 📦 Add extra repositories (TUR, glibc, X11, root)
- 🖥️ Configure build environment variables
- 📱 Supports all Termux architectures (arm, aarch64, x86, x86_64)

## Installation

1. Ensure you have Termux installed
2. Run the following commands:

```
curl -LO https://raw.githubusercontent.com/thetechstoner/termux-manager/main/termux-manager.sh
chmod +x ./termux-manager.sh
bash ./termux-manager.sh
```

## Usage

Run the script and select from the menu:

```
Termux Environment Manager
select a choice:
1) Restore Termux backup
2) Backup Termux
3) switch package manager in termux
4) Setup Termux GUI
5) Setup Build Environment
6) Add Repositories to Termux
7) Exit
```

### Package Manager Switching
- Choose between apt (default) or pacman-based environments
- Automatically downloads correct bootstrap for your architecture

### Backup/Restore
- Creates compressed backups in `/sdcard/termux-backup.tar.gz`
- Restores complete environments

### Build Environment
- Installs essential tools (git, compilers, etc.)
- Configures proper environment variables
- Sets up paths for development

## Requirements

- Termux app
- Internet connection
- will automatically grant Storage permission
- will automatically install missing packages

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you'd like to change.

## License

[MIT](https://choosealicense.com/licenses/mit/)

---

**Note**: This script modifies core Termux files. Use with caution and always maintain backups.
