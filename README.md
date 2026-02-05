# Universal SOC Installer

Open-source tool to set up a comprehensive SOC Analyst workstation on Windows and Linux with a single command.

## Supported Platforms
- **Windows**: Windows 10/11 (PowerShell)
- **Linux**: Debian/Ubuntu, RHEL/CentOS, Arch Linux (Bash)

## Configuration
Tools are configured via `tools.json`. You can add or remove tools by editing this file.
- **Windows**: Defines Winget/Chocolatey IDs.
- **Linux**: Defines package names for `apt`, `dnf`, `pacman`, and `pip`.

## Logging
Installation logs are written to `install.log` in the script directory.

## Quick Start (The "Single Command")

### Windows (PowerShell Administrator)
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/PrototypePrime/Hyper-SOC/main/windows/install.ps1'))
```
*(Note: Replace URL with actual raw GitHub URL after pushing)*

### Linux (Bash)
```bash
curl -sL https://raw.githubusercontent.com/PrototypePrime/Hyper-SOC/main/linux/install.sh | sudo bash
```

## Included Tools

### Windows
- **Network**: Nmap, Wireshark, Putty
- **Forensics**: Sysinternals Suite, Eric Zimmerman's Tools, Velociraptor
- **Utilities**: 7Zip, Notepad++, Git, VS Code, Python 3
- **Web**: Burp Suite Community
- **Static Analysis**: Ghidra, IDA Free, x64dbg, PEStudio, CFF Explorer, HxD, Capa, Floss

### Linux
- **Network**: Nmap, Wireshark, Tcpdump, Masscan
- **Forensics**: Volatility 3, The Sleuth Kit (TSK), YARA, Binwalk, Exiftool
- **Utilities**: jq, htop, tmux, git, curl, wget
- **Static Analysis**: Ghidra, Radare2, GDB, Oletools, Capa, Floss

## Contributing
Pull requests are welcome. Please open an issue first to discuss what you would like to change.
