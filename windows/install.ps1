<#
.SYNOPSIS
    Hyper-SOC: Universal SOC Analysis Tool Installer for Windows
.DESCRIPTION
    Installs a comprehensive suite of SOC analysis tools using functionality from Winget and Chocolatey.
    Includes Network, Forensics, Utilities, and Static Malware Analysis tools.
    Supports external configuration via tools.json (local or remote).
.NOTES
    Author: Hyper-SOC Team
    Date: 2026-02-05
#>

# --- Configuration ---
param (
    [switch]$DryRun,
    [string]$ConfigPath = "..\tools.json",
    [string]$ConfigUrl = "https://raw.githubusercontent.com/PrototypePrime/Hyper-SOC/main/tools.json",
    [string]$LogPath = ".\install.log"
)

$ErrorActionPreference = "Stop"

# --- Logging Function ---
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO",
        [ConsoleColor]$Color = "White"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    # Write to Host
    Write-Host $Message -ForegroundColor $Color
    
    # Write to File
    if (-not $DryRun) {
        $LogEntry | Out-File -FilePath $LogPath -Append -Encoding utf8
    }
}

# --- Load Configuration ---
if (-not (Test-Path $ConfigPath)) {
    Write-Log "[!] Configuration file not found locally at $ConfigPath." -Level "WARNING" -Color Yellow
    Write-Log "[*] Attempting to download from GitHub..." -Color Cyan
    
    $TempConfig = "$env:TEMP\tools.json"
    try {
        if (-not $DryRun) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $ConfigUrl -OutFile $TempConfig -UseBasicParsing
        }
        else {
            Write-Log "[DRY RUN] Would download config from $ConfigUrl to $TempConfig" -Level "DRYRUN" -Color Gray
            # Create dummy file for dry run parsing if real one missing
            if (-not (Test-Path $TempConfig)) {
                Write-Log "[DRY RUN] Mocking tools.json content for dry run execution..." -Level "DRYRUN" -Color Gray
                Set-Content -Path $TempConfig -Value '{ "windows": [] }'
            }
        }
        
        if (Test-Path $TempConfig) {
            $ConfigPath = $TempConfig
            Write-Log "[+] Configuration downloaded successfully." -Color Green
        }
    }
    catch {
        Write-Log "[!] Failed to download configuration: $_" -Level "ERROR" -Color Red
        if (-not $DryRun) { Exit 1 }
    }
}

if (Test-Path $ConfigPath) {
    Write-Log "[*] Loading configuration from $ConfigPath" -Color Cyan
    try {
        $JsonContent = Get-Content -Raw -Path $ConfigPath | ConvertFrom-Json
        $Tools = $JsonContent.windows
    }
    catch {
        Write-Log "[!] Failed to parse JSON configuration." -Level "FATAL" -Color Red
        Exit 1
    }
}
else {
    if ($DryRun) {
        Write-Log "[DRY RUN] No config file found. Using empty tool list." -Level "DRYRUN" -Color Gray
        $Tools = @()
    }
    else {
        Write-Log "[!] Failed to load configuration." -Level "FATAL" -Color Red
        Exit 1
    }
}

# --- Functions ---

function Test-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$currentUser
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-Chocolatey {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "[+] Installing Chocolatey..." -Color Cyan
        Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    else {
        Write-Log "[*] Chocolatey is already installed." -Color Green
    }
}

function Install-Tool {
    param (
        [Parameter(Mandatory = $true)] $Tool,
        [switch] $DryRun
    )
    
    if ($DryRun) {
        Write-Log "[DRY RUN] Would install $($Tool.Name) (ID: $($Tool.Id)) via $($Tool.Source)" -Level "DRYRUN" -Color Gray
        return
    }

    Write-Log "`n[->] Installing $($Tool.Name)..." -Color Yellow

    try {
        if ($Tool.Source -eq "winget") {
            winget install --id $Tool.Id -e --silent --accept-package-agreements --accept-source-agreements
        }
        elseif ($Tool.Source -eq "chocolatey") {
            choco install $Tool.Id -y
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "[OK] $($Tool.Name) installed successfully." -Level "SUCCESS" -Color Green
        }
        else {
            Write-Log "[!] Error installing $($Tool.Name). Exit Code: $LASTEXITCODE" -Level "ERROR" -Color Red
        }
    }
    catch {
        Write-Log "[!] Exception installing $($Tool.Name): $_" -Level "ERROR" -Color Red
    }
}

function Install-VSCodeExtensions {
    Write-Log "`n[->] Configuring VS Code Extensions..." -Color Yellow
    $Extensions = @(
        "ms-python.python",
        "ms-azuretools.vscode-docker",
        "pkief.material-icon-theme",
        "redhat.vscode-yaml"
    )

    if ($DryRun) {
        foreach ($ext in $Extensions) {
            Write-Log "[DRY RUN] Would install VS Code extension: $ext" -Level "DRYRUN" -Color Gray
        }
        return
    }

    if (Get-Command code -ErrorAction SilentlyContinue) {
        foreach ($ext in $Extensions) {
            try {
                Write-Log "    Installing $ext..." -Color Cyan
                code --install-extension $ext --force | Out-Null
            }
            catch {
                Write-Log "[!] Failed to install extension $ext" -Level "ERROR" -Color Red
            }
        }
    }
    else {
        Write-Log "[!] VS Code ('code' command) not found in PATH. Skipping extensions." -Level "WARNING" -Color Yellow
    }
}

# --- Main Instllation Flow ---

Write-Log "
  _   _                      ____   ___   ____ 
 | | | |_   _ _ __   ___ _  / ___| / _ \ / ___|
 | |_| | | | | '_ \ / _ \ '__\___ \| | | | |    
 |  _  | |_| | |_) |  __/ |    ___) | |_| | |___ 
 |_| |_|\__, | .__/ \___|_|   |____/ \___/ \____|
        |___/|_|                                 
 Universal SOC Installer - Windows
" -Color Cyan

if ($DryRun) { Write-Log "=== DRY RUN MODE ACTIVE ===" -Level "INFO" -Color Magenta }

if (-not (Test-Admin)) {
    if ($DryRun) {
        Write-Log "[!] Not running as Admin, but continuing due to Dry Run." -Level "WARNING" -Color Yellow
    }
    else {
        Write-Log "[!] Script must be run as Administrator!" -Level "FATAL" -Color Red
        Exit 1
    }
}

# Ensure Package Managers
if (-not $DryRun) {
    Install-Chocolatey
}
else {
    Write-Log "[DRY RUN] Would check/install Chocolatey" -Level "DRYRUN" -Color Gray
}

# Install Tools
if ($Tools) {
    foreach ($tool in $Tools) {
        Install-Tool -Tool $tool -DryRun:$DryRun
    }
}

# Post-Install Configuration
Install-VSCodeExtensions

Write-Log "`n[+] Installation Complete! Some tools may require a restart." -Level "SUCCESS" -Color Green
