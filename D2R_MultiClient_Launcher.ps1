Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Configuration
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configFile = Join-Path $scriptDir "D2R_Launcher.config.json"
$handleExe = "C:\Tools\handle.exe"  # Adjust path if handle.exe is elsewhere
$battleNetExe = "C:\Program Files (x86)\Battle.net\Battle.net Launcher.exe"  # Default Battle.net path

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
    
    foreach ($process in $d2rProcesses) {
        try {
            $processPath = $process.Path
            $processDir = Split-Path $processPath -Parent
            
            for ($i = 0; $i -lt 5; $i++) {
                $clientPath = $clientPathBoxes[$i].Text.Trim()
                if ($clientPath -and (Test-Path $clientPath)) {
                    $clientD2R = Join-Path $clientPath "D2R.exe"
                    if ($processDir -eq $clientPath -or $processPath -eq $clientD2R) {
                        $runningClients += $i
                        break
                    }
                }
            }
        } catch {
            # Process path might not be accessible
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
    
    if (-not (Test-Path $handleExe)) {
        return $false
    }
    
    if (-not ($d2rProcesses -is [System.Array])) {
        $d2rProcesses = @($d2rProcesses)
    }
    
    $targetHandleName = "DiabloII Check For Other Instances"
    $closedCount = 0
    
    foreach ($d2rProcess in $d2rProcesses) {
        $processId = $d2rProcess.Id
        
        try {
            $handleOutput = & $handleExe -p $processId -a 2>&1 | Out-String
            
            if ($handleOutput -match [regex]::Escape($targetHandleName)) {
                $lines = $handleOutput -split "`r?`n"
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($lines[$i] -match [regex]::Escape($targetHandleName)) {
                        for ($j = $i; $j -ge 0 -and ($i - $j) -le 3; $j--) {
                            if ($lines[$j] -match "^\s*([0-9A-Fa-f]+):\s*Event") {
                                $handleNum = $matches[1]
                                & $handleExe -c $handleNum -p $processId -y 2>&1 | Out-Null
                                if ($LASTEXITCODE -eq 0) {
                                    $closedCount++
                                }
                                break
                            }
                        }
                    }
                }
            }
        } catch {
            # Ignore errors
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
    
    Close-AllHandles | Out-Null
    Start-Sleep -Milliseconds 500
    
    # Launch Battle.net
    if (-not (Test-Path $battleNetExe)) {
        [System.Windows.Forms.MessageBox]::Show("Battle.net Launcher not found at:`n$battleNetExe`n`nPlease update the path in the script.", "Battle.net Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    try {
        # Launch Battle.net launcher
        # Note: Battle.net will need to be configured to use the correct game folder
        Start-Process $battleNetExe -WorkingDirectory (Split-Path $battleNetExe -Parent)
        
        $resultLabel.Text = "Launched Battle.net for Client $($clientIndex + 1).`n`nGame folder: $clientPath`n`nPlease log in with your account and launch D2R from Battle.net."
        $resultLabel.ForeColor = [System.Drawing.Color]::Green
        
        # Refresh status after delay
        Start-Sleep -Seconds 3
        Update-ClientStatus
    } catch {
        $resultLabel.Text = "Error launching Battle.net: $($_.Exception.Message)"
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
        $d2rExe = Join-Path $selectedPath "D2R.exe"
        
        if (Test-Path $d2rExe) {
            $clientPathBoxes[$clientIndex].Text = $selectedPath
            Save-Config
            Update-ClientStatus
        } else {
            [System.Windows.Forms.MessageBox]::Show("D2R.exe not found in selected folder.`nPlease select the game folder containing D2R.exe", "Invalid Folder", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
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
