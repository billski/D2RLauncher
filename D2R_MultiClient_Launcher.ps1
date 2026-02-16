Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Configuration
# Get script directory - works even if script is run from different location
if ($MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $scriptDir = $PSScriptRoot
}
$configFile = Join-Path $scriptDir "D2R_Launcher.config.json"
$handleExe = Join-Path $scriptDir "handle.exe"  # Local copy in app folder
$battleNetExe = "C:\Program Files (x86)\Battle.net\Battle.net Launcher.exe"  # Default Battle.net path (not used, kept for reference)

# Config file structure: {"clients": [{"path": "...", "name": "Client 1"}, ...]}

# Function to load config
function Load-Config {
    if (Test-Path $configFile) {
        try {
            $content = Get-Content $configFile -Raw | ConvertFrom-Json
            return $content.clients
        } catch {
            return @()
        }
    }
    return @()
}

# Function to save config
function Save-Config {
    $clients = @()
    for ($i = 0; $i -lt 5; $i++) {
        $path = $clientPathBoxes[$i].Text.Trim()
        if ($path) {
            $clients += @{
                path = $path
                name = "Client $($i + 1)"
            }
        }
    }
    $config = @{
        clients = $clients
    }
    $config | ConvertTo-Json | Set-Content $configFile
}

# Function to normalize path for comparison (removes trailing slashes, normalizes case)
function Normalize-PathForComparison {
    param([string]$path)
    if (-not $path) { return "" }
    # Convert to absolute path, remove trailing slashes, normalize case
    # Use Resolve-Path to handle any symlinks or relative paths
    try {
        $trimmed = $path.TrimEnd('\', '/')
        if ([System.IO.Path]::IsPathRooted($trimmed)) {
            $normalized = [System.IO.Path]::GetFullPath($trimmed)
        } else {
            $normalized = [System.IO.Path]::GetFullPath((Resolve-Path $trimmed -ErrorAction Stop).Path)
        }
        return $normalized.ToLower()
    } catch {
        # Fallback: just normalize what we have
        $trimmed = $path.TrimEnd('\', '/')
        return $trimmed.ToLower()
    }
}

# Function to get running clients
function Get-RunningClients {
    $runningClients = @()
    $d2rProcesses = Get-Process -Name "D2R" -ErrorAction SilentlyContinue
    if (-not $d2rProcesses) {
        return $runningClients
    }
    
    if (-not ($d2rProcesses -is [System.Array])) {
        $d2rProcesses = @($d2rProcesses)
    }
    
    # Build a map of normalized D2R.exe paths to their client indices
    # Only match by exact executable path to avoid ambiguity
    $clientExeMap = @{}
    for ($i = 0; $i -lt 5; $i++) {
        $clientPath = $clientPathBoxes[$i].Text.Trim()
        if ($clientPath -and (Test-Path $clientPath)) {
            # Get the exact expected D2R.exe path for this client
            # Use Resolve-Path to get the canonical path, then join
            try {
                $resolvedClientPath = (Resolve-Path $clientPath -ErrorAction Stop).Path
                $expectedD2RPath = Join-Path $resolvedClientPath "D2R.exe"
                # Verify the file actually exists at this path
                if (Test-Path $expectedD2RPath) {
                    $normalizedExePath = Normalize-PathForComparison $expectedD2RPath
                    # Store the mapping: normalized D2R.exe path -> client index
                    $clientExeMap[$normalizedExePath] = $i
                }
            } catch {
                # Path resolution failed, skip this client
            }
        }
    }
    
    # Match each process to exactly one client by exact executable path only
    foreach ($process in $d2rProcesses) {
        try {
            $processPath = $process.Path
            if (-not $processPath) { continue }
            
            # Normalize the actual process executable path
            $normalizedProcessPath = Normalize-PathForComparison $processPath
            
            # Match ONLY by exact executable path (most reliable, no ambiguity)
            if ($clientExeMap.ContainsKey($normalizedProcessPath)) {
                $matchedIndex = $clientExeMap[$normalizedProcessPath]
                # Only add if not already in the list (prevent duplicates)
                if ($runningClients -notcontains $matchedIndex) {
                    $runningClients += $matchedIndex
                }
            }
            # If no match found, this process doesn't belong to any configured client
        } catch {
            # Process path might not be accessible, skip this process
        }
    }
    
    return $runningClients
}

# Function to update client status
function Update-ClientStatus {
    $runningClients = Get-RunningClients
    
    for ($i = 0; $i -lt 5; $i++) {
        $isRunning = $runningClients -contains $i
        $clientRunButtons[$i].Enabled = -not $isRunning
        
        if ($isRunning) {
            $clientStatusLabels[$i].Text = "Running"
            $clientStatusLabels[$i].ForeColor = [System.Drawing.Color]::Green
        } else {
            $clientStatusLabels[$i].Text = "Stopped"
            $clientStatusLabels[$i].ForeColor = [System.Drawing.Color]::Gray
        }
    }
    
    $runningCount = $runningClients.Count
    $statusLabel.Text = "Status: $runningCount client(s) running"
    if ($runningCount -gt 0) {
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $statusLabel.ForeColor = [System.Drawing.Color]::Gray
    }
}

# Function to close handles from all running clients
function Close-AllHandles {
    $d2rProcesses = Get-Process -Name "D2R" -ErrorAction SilentlyContinue
    if (-not $d2rProcesses) {
        return $true
    }
    
    # Verify handle.exe exists and is accessible
    if (-not (Test-Path $handleExe)) {
        return $false
    }
    
    # Get absolute path to handle.exe to avoid any path resolution issues
    $handleExeFullPath = (Resolve-Path $handleExe -ErrorAction Stop).Path
    
    if (-not ($d2rProcesses -is [System.Array])) {
        $d2rProcesses = @($d2rProcesses)
    }
    
    $targetHandleName = "DiabloII Check For Other Instances"
    $closedCount = 0
    
    foreach ($d2rProcess in $d2rProcesses) {
        $processId = $d2rProcess.Id
        
        try {
            # Execute handle.exe using Start-Process for better reliability
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $handleExeFullPath
            $processInfo.Arguments = "-p $processId -a"
            $processInfo.UseShellExecute = $false
            $processInfo.RedirectStandardOutput = $true
            $processInfo.RedirectStandardError = $true
            $processInfo.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $processInfo
            $process.Start() | Out-Null
            $handleOutput = $process.StandardOutput.ReadToEnd()
            $errorOutput = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            
            # Combine output and error streams
            $fullOutput = $handleOutput + $errorOutput
            
            if ($process.ExitCode -ne 0 -and $fullOutput -notmatch "No matching handles found") {
                # handle.exe failed, but continue trying other processes
                continue
            }
            
            if ($fullOutput -match [regex]::Escape($targetHandleName)) {
                $lines = $fullOutput -split "`r?`n"
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match [regex]::Escape($targetHandleName)) {
                        for ($j = $i; $j -ge 0 -and ($i - $j) -le 3; $j--) {
                            if ($lines[$j] -match "^\s*([0-9A-Fa-f]+):\s*Event") {
                                $handleNum = $matches[1]
                                
                                # Close the handle
                                $closeProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                                $closeProcessInfo.FileName = $handleExeFullPath
                                $closeProcessInfo.Arguments = "-c $handleNum -p $processId -y"
                                $closeProcessInfo.UseShellExecute = $false
                                $closeProcessInfo.RedirectStandardOutput = $true
                                $closeProcessInfo.RedirectStandardError = $true
                                $closeProcessInfo.CreateNoWindow = $true
                                
                                $closeProcess = New-Object System.Diagnostics.Process
                                $closeProcess.StartInfo = $closeProcessInfo
                                $closeProcess.Start() | Out-Null
                                $closeProcess.WaitForExit()
                                
                                if ($closeProcess.ExitCode -eq 0) {
                                    $closedCount++
                                }
                                break
                            }
                        }
                    }
                }
            }
        } catch {
            # If handle.exe execution fails, continue with next process
            continue
        }
    }
    
    return $closedCount -gt 0
}

# Function to launch client
function Launch-Client {
    param([int]$clientIndex)
    
    $clientPath = $clientPathBoxes[$clientIndex].Text.Trim()
    
    if (-not $clientPath) {
        [System.Windows.Forms.MessageBox]::Show("Please set a path for Client $($clientIndex + 1) first.", "No Path Set", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    if (-not (Test-Path $clientPath)) {
        [System.Windows.Forms.MessageBox]::Show("Path does not exist:`n$clientPath", "Invalid Path", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    $clientD2R = Join-Path $clientPath "D2R.exe"
    if (-not (Test-Path $clientD2R)) {
        [System.Windows.Forms.MessageBox]::Show("D2R.exe not found in:`n$clientPath", "Invalid Game Folder", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    # Check if already running
    $runningClients = Get-RunningClients
    if ($runningClients -contains $clientIndex) {
        [System.Windows.Forms.MessageBox]::Show("Client $($clientIndex + 1) is already running.", "Already Running", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    # Close handles from all running clients
    $resultLabel.Text = "Closing handles from running clients..."
    $resultLabel.ForeColor = [System.Drawing.Color]::Blue
    $form.Refresh()
    
    # Verify handle.exe exists before trying to use it
    if (-not (Test-Path $handleExe)) {
        [System.Windows.Forms.MessageBox]::Show("handle.exe not found at:`n$handleExe`n`nPlease ensure handle.exe is in the same folder as this script.", "handle.exe Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        $resultLabel.Text = "Error: handle.exe not found. Cannot launch multiple clients."
        $resultLabel.ForeColor = [System.Drawing.Color]::Red
        return
    }
    
    $handlesClosed = Close-AllHandles
    if (-not $handlesClosed) {
        # Handles might not exist (first client) or handle.exe failed
        # Continue anyway - the launcher will handle it
    }
    Start-Sleep -Milliseconds 500
    
    # Launch Diablo II Resurrected Launcher
    $launcherExe = Join-Path $clientPath "Diablo II Resurrected Launcher.exe"
    if (-not (Test-Path $launcherExe)) {
        [System.Windows.Forms.MessageBox]::Show("Diablo II Resurrected Launcher.exe not found in:`n$clientPath`n`nPlease ensure the launcher file exists in the game folder.", "Launcher Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    try {
        # Launch the Diablo II Resurrected Launcher
        Start-Process $launcherExe -WorkingDirectory $clientPath
        
        $resultLabel.Text = "Launched Client $($clientIndex + 1).`n`nGame folder: $clientPath`n`nLauncher: Diablo II Resurrected Launcher.exe"
        $resultLabel.ForeColor = [System.Drawing.Color]::Green
        
        # Refresh status after delay
        Start-Sleep -Seconds 3
        Update-ClientStatus
    } catch {
        $resultLabel.Text = "Error launching client: $($_.Exception.Message)"
        $resultLabel.ForeColor = [System.Drawing.Color]::Red
    }
}

# Function to browse for folder
function Browse-ClientPath {
    param([int]$clientIndex)
    
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select Diablo II Resurrected game folder for Client $($clientIndex + 1)"
    $folderDialog.ShowNewFolderButton = $false
    
    if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPath = $folderDialog.SelectedPath
        $launcherExe = Join-Path $selectedPath "Diablo II Resurrected Launcher.exe"
        
        if (Test-Path $launcherExe) {
            $clientPathBoxes[$clientIndex].Text = $selectedPath
            Save-Config
            Update-ClientStatus
        } else {
            [System.Windows.Forms.MessageBox]::Show("Diablo II Resurrected Launcher.exe not found in selected folder.`nPlease select the game folder containing the launcher.", "Invalid Folder", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
}

# Create main form
$form = New-Object System.Windows.Forms.Form
$form.Text = "D2R Multi-Client Launcher"
$form.Size = New-Object System.Drawing.Size(900, 650)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Set icon if it exists
$iconPath = Join-Path $scriptDir "D2R_Launcher.ico"
if (Test-Path $iconPath) {
    try {
        $form.Icon = New-Object System.Drawing.Icon($iconPath)
    } catch {
        # Icon loading failed, continue without icon
    }
}

# Status label
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(10, 10)
$statusLabel.Size = New-Object System.Drawing.Size(870, 25)
$statusLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 10, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($statusLabel)

# Info label
$infoLabel = New-Object System.Windows.Forms.Label
$infoLabel.Location = New-Object System.Drawing.Point(10, 40)
$infoLabel.Size = New-Object System.Drawing.Size(870, 40)
$infoLabel.Text = "Configure up to 5 game folder paths. Each client can run with a different Battle.net account."
$infoLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$form.Controls.Add($infoLabel)

# Client path controls (5 clients)
$clientPathBoxes = @()
$clientBrowseButtons = @()
$clientRunButtons = @()
$clientStatusLabels = @()

$yStart = 90
for ($i = 0; $i -lt 5; $i++) {
    $yPos = $yStart + ($i * 50)
    
    # Client label
    $clientLabel = New-Object System.Windows.Forms.Label
    $clientLabel.Location = New-Object System.Drawing.Point(10, ($yPos + 3))
    $clientLabel.Size = New-Object System.Drawing.Size(80, 20)
    $clientLabel.Text = "Client $($i + 1):"
    $clientLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
    $form.Controls.Add($clientLabel)
    
    # Path textbox
    $pathBox = New-Object System.Windows.Forms.TextBox
    $pathBox.Location = New-Object System.Drawing.Point(95, $yPos)
    $pathBox.Size = New-Object System.Drawing.Size(500, 25)
    $pathBox.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
    $form.Controls.Add($pathBox)
    $clientPathBoxes += $pathBox
    
    # Browse button
    $browseBtn = New-Object System.Windows.Forms.Button
    $browseBtn.Location = New-Object System.Drawing.Point(600, $yPos)
    $browseBtn.Size = New-Object System.Drawing.Size(80, 25)
    $browseBtn.Text = "Browse"
    $browseBtn.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
    $browseIndex = $i
    $browseBtn.Add_Click([scriptblock]::Create("Browse-ClientPath $browseIndex"))
    $form.Controls.Add($browseBtn)
    $clientBrowseButtons += $browseBtn
    
    # Status label
    $statusLbl = New-Object System.Windows.Forms.Label
    $statusLbl.Location = New-Object System.Drawing.Point(685, ($yPos + 3))
    $statusLbl.Size = New-Object System.Drawing.Size(60, 20)
    $statusLbl.Text = "Stopped"
    $statusLbl.ForeColor = [System.Drawing.Color]::Gray
    $statusLbl.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
    $form.Controls.Add($statusLbl)
    $clientStatusLabels += $statusLbl
    
    # Run button
    $runBtn = New-Object System.Windows.Forms.Button
    $runBtn.Location = New-Object System.Drawing.Point(750, $yPos)
    $runBtn.Size = New-Object System.Drawing.Size(120, 25)
    $runBtn.Text = "Run Client $($i + 1)"
    $runBtn.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
    $runIndex = $i
    $runBtn.Add_Click([scriptblock]::Create("Launch-Client $runIndex"))
    $form.Controls.Add($runBtn)
    $clientRunButtons += $runBtn
}

# Buttons at bottom
$closeHandleButton = New-Object System.Windows.Forms.Button
$closeHandleButton.Location = New-Object System.Drawing.Point(10, 350)
$closeHandleButton.Size = New-Object System.Drawing.Size(180, 35)
$closeHandleButton.Text = "Close All Handles"
$closeHandleButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$closeHandleButton.Add_Click({
    $resultLabel.Text = "Closing handles from all running clients..."
    $resultLabel.ForeColor = [System.Drawing.Color]::Blue
    $form.Refresh()
    if (Close-AllHandles) {
        $resultLabel.Text = "Successfully closed handles. You can now launch new clients."
        $resultLabel.ForeColor = [System.Drawing.Color]::Green
    } else {
        $resultLabel.Text = "No handles found to close, or handle.exe not available."
        $resultLabel.ForeColor = [System.Drawing.Color]::Blue
    }
    Update-ClientStatus
})
$form.Controls.Add($closeHandleButton)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Location = New-Object System.Drawing.Point(200, 350)
$refreshButton.Size = New-Object System.Drawing.Size(180, 35)
$refreshButton.Text = "Refresh Status"
$refreshButton.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$refreshButton.Add_Click({ Update-ClientStatus })
$form.Controls.Add($refreshButton)

# Result label
$resultLabel = New-Object System.Windows.Forms.Label
$resultLabel.Location = New-Object System.Drawing.Point(10, 400)
$resultLabel.Size = New-Object System.Drawing.Size(870, 200)
$resultLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9)
$resultLabel.Text = "Configure your client paths using the Browse buttons, then click Run to launch each client."
$form.Controls.Add($resultLabel)

# Load config on startup
$loadedClients = Load-Config
for ($i = 0; $i -lt 5 -and $i -lt $loadedClients.Count; $i++) {
    if ($loadedClients[$i].path) {
        $clientPathBoxes[$i].Text = $loadedClients[$i].path
    }
}

# Initial status update
Update-ClientStatus

# Auto-refresh status every 5 seconds
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({ Update-ClientStatus })
$timer.Start()

# Show form
[void]$form.ShowDialog()

$timer.Stop()
