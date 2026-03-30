# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the Launcher

```bat
Launch_D2R_Launcher.bat
```

This batch file checks for admin rights (required for `handle.exe` to close D2R process handles) and launches the PowerShell script with `-ExecutionPolicy Bypass`. There is no build step — the `.ps1` script runs directly.

To run the script manually (from an elevated PowerShell):
```powershell
powershell.exe -ExecutionPolicy Bypass -File .\D2R_MultiClient_Launcher.ps1
```

## Architecture

The entire application is a single self-contained PowerShell script (`D2R_MultiClient_Launcher.ps1`) using Windows Forms for the GUI.

**Key design decisions:**

- All 8 client UI rows are created at startup and shown/hidden dynamically — the UI never adds or removes controls at runtime.
- Client detection uses exact D2R.exe path matching (`Normalize-PathForComparison` → lowercased absolute path) to avoid false positives when multiple clients run from different folders.
- Handle closing (`Close-AllHandles`) calls `handle.exe -p <PID> -a` to list handles, finds the `DiabloII Check For Other Instances` event handle by scanning lines above the match for a hex handle ID, then calls `handle.exe -c <handle> -p <PID> -y` to close it. This is what allows multiple simultaneous instances.
- Config is persisted to `D2R_Launcher.config.json` (same directory as the script) as `{"clients": [...], "clientCount": N}`. Config is loaded at startup and saved on any path change or client count change.
- Status auto-refreshes every 5 seconds via a `System.Windows.Forms.Timer`.

**Script-scoped variables** that are shared between functions: `$currentClientCount`, plus the UI control arrays (`$clientPathBoxes`, `$clientRunButtons`, `$clientStatusLabels`, etc.) which are defined in the outer scope and accessed directly by functions.

**Important closure gotcha:** Button click handlers use `[scriptblock]::Create("FunctionName $index")` (string-based) rather than direct scriptblocks to correctly capture the loop index. Direct `{ Launch-Client $i }` would close over the loop variable and all buttons would use the last value of `$i`.

## Files

| File | Purpose |
|------|---------|
| `D2R_MultiClient_Launcher.ps1` | Entire application |
| `Launch_D2R_Launcher.bat` | Entry point — elevates to admin and runs the PS1 |
| `D2R_Launcher.config.json` | Auto-generated config (gitignored is fine) |
| `handle.exe` | Sysinternals Handle utility (must be present alongside the PS1) |
| `D2R_Launcher.ico` | Window icon (optional, loaded at runtime) |
