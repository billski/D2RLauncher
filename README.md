# D2R Multi-Client Launcher

A simple tool to run multiple Diablo II Resurrected clients on the same computer. Perfect for running multiple accounts at once!

## What This Does

- Lets you run up to 8 Diablo II Resurrected clients at the same time
- Choose how many clients you want (2-8) with a simple dropdown
- Defaults to 3 clients for easy setup
- Each client can use a different Battle.net account
- Automatically closes handles so you can launch multiple clients
- Shows you which clients are running
- Saves your settings so you don't have to set them up every time

## Requirements

Before you start, make sure you have:

- Windows 10 or Windows 11
- Multiple copies of your Diablo II Resurrected game folder (one copy for each account you want to run)

**Note:** `handle.exe` is included in this package - you don't need to download it separately!

## Simple Step-by-Step Guide

### Step 1: Configure Battle.net Settings

**IMPORTANT:** You must configure Battle.net before using this launcher!

1. Open Battle.net launcher
2. Click the **Settings** icon (gear icon in the top left)
3. Go to **Game Settings**
4. Find **Diablo II Resurrected** in the list
5. Check these two settings:
   - ✅ **"Close Battle.net when a game launches"** - This MUST be enabled
   - ✅ **"Allow multiple instances of Battle.net"** - This MUST be enabled
6. Click **Done** to save

**Why?** These settings allow each game client to run with its own Battle.net instance, so you can use different accounts.

### Step 2: Copy Your Game Folder

You need a separate copy of the game folder for each account you want to run.

1. Find your Diablo II Resurrected installation folder
   - Usually something like: `C:\Program Files (x86)\Diablo II Resurrected`
2. Copy the entire folder
3. Paste it somewhere convenient (like `C:\Games\`)
4. Rename each copy so you can tell them apart:
   - `C:\Games\D2R_Client1`
   - `C:\Games\D2R_Client2`
   - `C:\Games\D2R_Client3`
   - `C:\Games\D2R_Client4`
   - etc. (up to 8 clients)

**Important:** Each copy must be in a different folder. Don't just make shortcuts!

### Step 3: Run the Launcher

1. Double-click `Launch_D2R_Launcher.bat`
2. If Windows asks for administrator permission, click "Yes"
3. The launcher window will open

### Step 4: Choose Number of Clients

1. At the top of the launcher, you'll see a dropdown labeled **"Number of Clients"**
2. Select how many clients you want to use (2-8)
   - The default is 3 clients
   - The interface will automatically show or hide client rows based on your selection

### Step 5: Set Up Your Clients

1. For each visible client:
   - Click the **"Browse"** button next to "Client 1:", "Client 2:", etc.
   - Navigate to and select the game folder for that client
   - The path will appear in the text box
   - Repeat for each client you want to use

2. Your settings are saved automatically - you won't need to do this again!

### Step 6: Launch a Client

1. Click the **"Run Client X"** button for the client you want to launch
2. The launcher will:
   - Close handles from other running clients
   - Launch "Diablo II Resurrected Launcher.exe" from that client's folder
3. Log in with your Battle.net account when prompted
4. The status will show "Running" in green when the client is active

### Step 7: Launch More Clients

1. Click "Run Client X" for another client
2. Log in with a different Battle.net account
3. You can run up to 8 clients at the same time (depending on your selection)!

## Understanding the Interface

- **Status Label (top)**: Shows how many clients are currently running
- **Number of Clients Dropdown**: Select how many clients to show (2-8). Default is 3.
- **Client Path Box**: Shows the folder path for each client
- **Browse Button**: Lets you select the game folder for that client
- **Status (Stopped/Running)**: Shows if that client is currently running
- **Run Client X Button**: Launches that client
- **Close All Handles Button**: Manually closes handles (usually done automatically)
- **Refresh Status Button**: Updates the status of all clients

**Note:** The interface automatically adjusts when you change the number of clients. The form will resize and show/hide client rows as needed.

## Advanced Setup

**Note:** `handle.exe` is included in the app folder and will be used automatically. You don't need to configure it.

### Troubleshooting

**Problem: "handle.exe not found"**
- Make sure `handle.exe` is in the same folder as `D2R_MultiClient_Launcher.ps1`
- If it's missing, you can download it from: https://learn.microsoft.com/en-us/sysinternals/downloads/handle

**Problem: "Diablo II Resurrected Launcher.exe not found"**
- Make sure you selected the correct game folder
- The folder must contain "Diablo II Resurrected Launcher.exe"

**Problem: Can't launch a second client**
- Make sure Battle.net settings are configured correctly (see Step 1)
- Make sure the first client is fully loaded
- Try clicking "Close All Handles" button, then launch again
- Make sure you're using different game folder copies (not the same folder)
- Make sure you're logging in with a different Battle.net account for each client

**Problem: Path goes to wrong client when clicking Browse**
- This was a bug that should be fixed. If it still happens, restart the launcher.

## How It Works (Technical)

- Each client needs its own game folder copy
- The launcher supports up to 8 clients, with a configurable number shown in the interface (default: 3)
- The launcher detects which clients are running by checking process paths
- Before launching a new client, it automatically closes the "check for other instances" handle from all running clients using `handle.exe`
- The launcher runs "Diablo II Resurrected Launcher.exe" from each client's folder
- Settings including the selected client count are saved in `D2R_Launcher.config.json`

## Files

- `D2R_MultiClient_Launcher.ps1` - Main launcher script (don't edit unless you know what you're doing)
- `D2R_Launcher.config.json` - Config file storing client paths (auto-generated)
- `Launch_D2R_Launcher.bat` - Batch file to launch the app with admin rights
- `README.md` - This file

## Notes

- You need administrator rights to close handles (the batch file requests this automatically)
- Each game folder copy takes up disk space (the full game size for each copy)
- Make sure each copy is a complete installation with all game files
