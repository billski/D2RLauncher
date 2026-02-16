# D2R Multi-Client Launcher

A PowerShell GUI application to launch multiple Diablo II Resurrected clients with different Battle.net accounts.

## Features

- Support for up to 5 different game folder installations
- Automatic detection of running clients
- Automatic handle closing before launching new clients
- Config file to save client paths
- Visual status indicators for each client

## Setup

1. **Copy your game folder** multiple times (one for each account you want to run)
   - Example: `C:\Games\D2R_Client1`, `C:\Games\D2R_Client2`, etc.

2. **Configure handle.exe path** (if different from default)
   - Edit `D2R_MultiClient_Launcher.ps1`
   - Change line 6: `$handleExe = "C:\Tools\handle.exe"`

3. **Configure Battle.net path** (if different from default)
   - Edit `D2R_MultiClient_Launcher.ps1`
   - Change line 7: `$battleNetExe = "C:\Program Files (x86)\Battle.net\Battle.net Launcher.exe"`

## Usage

1. Run `Launch_D2R_Launcher.bat` (will request admin rights automatically)
2. Click "Browse" for each client to select the game folder
3. Click "Run Client X" to launch that client
4. Log in with different Battle.net accounts in each Battle.net instance

## How It Works

- Each client needs its own game folder copy
- The launcher detects which clients are running by checking process paths
- Before launching a new client, it closes the "check for other instances" handle from all running clients
- Battle.net launcher is launched, allowing you to log in with different accounts

## Files

- `D2R_MultiClient_Launcher.ps1` - Main launcher script
- `D2R_Launcher.config.json` - Config file storing client paths
- `Launch_D2R_Launcher.bat` - Batch file to launch the app with admin rights
- `README.md` - This file

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- handle.exe from Sysinternals (for closing handles)
- Multiple copies of Diablo II Resurrected game folder
