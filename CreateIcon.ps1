# Script to create an icon file for D2R Multi-Client Launcher
Add-Type -AssemblyName System.Drawing

$iconPath = Join-Path $PSScriptRoot "D2R_Launcher.ico"

try {
    # Create a 256x256 bitmap for the icon
    $bitmap = New-Object System.Drawing.Bitmap(256, 256)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)

    # Set high quality rendering
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias

    # Create a gradient background (dark red/orange theme for Diablo)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        [System.Drawing.Point]::new(0, 0),
        [System.Drawing.Point]::new(256, 256),
        [System.Drawing.Color]::FromArgb(139, 0, 0),  # Dark red
        [System.Drawing.Color]::FromArgb(255, 69, 0)  # Dark orange
    )
    $graphics.FillRectangle($brush, 0, 0, 256, 256)

    # Draw a stylized "D2R" text
    $font = New-Object System.Drawing.Font("Arial", 100, [System.Drawing.FontStyle]::Bold)
    $textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $textFormat = New-Object System.Drawing.StringFormat
    $textFormat.Alignment = [System.Drawing.StringAlignment]::Center
    $textFormat.LineAlignment = [System.Drawing.StringAlignment]::Center

    # Draw "D2R" text
    $graphics.DrawString("D2R", $font, $textBrush, 128, 100, $textFormat)

    # Add a small "M" for Multi below (smaller font)
    $smallFont = New-Object System.Drawing.Font("Arial", 50, [System.Drawing.FontStyle]::Bold)
    $graphics.DrawString("M", $smallFont, $textBrush, 128, 180, $textFormat)

    # Save as PNG first, then convert to ICO format
    $memoryStream = New-Object System.IO.MemoryStream
    $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngBytes = $memoryStream.ToArray()
    $memoryStream.Close()

    # Create ICO file with proper header
    $icoStream = New-Object System.IO.FileStream($iconPath, [System.IO.FileMode]::Create)
    $writer = New-Object System.IO.BinaryWriter($icoStream)
    
    # ICO file header (6 bytes)
    $writer.Write([byte]0)  # Reserved
    $writer.Write([byte]0)  # Reserved
    $writer.Write([byte]1)  # Type (1 = ICO)
    $writer.Write([byte]0)   # Type
    $writer.Write([byte]1)  # Number of images
    $writer.Write([byte]0)  # Number of images
    
    # Image directory entry (16 bytes)
    $writer.Write([byte]0)  # Width (0 = 256)
    $writer.Write([byte]0)  # Height (0 = 256)
    $writer.Write([byte]0)  # Color palette
    $writer.Write([byte]0)  # Reserved
    $writer.Write([byte]1)  # Color planes (low byte)
    $writer.Write([byte]0)  # Color planes (high byte)
    $writer.Write([byte]32) # Bits per pixel
    $writer.Write([byte]0)  # Bits per pixel (high byte)
    $imageDataSize = $pngBytes.Length
    $writer.Write([int32]$imageDataSize)  # Image data size
    $imageDataOffset = 22  # Header (6) + Directory entry (16)
    $writer.Write([int32]$imageDataOffset)  # Image data offset
    
    # Write PNG data
    $writer.Write($pngBytes)
    
    $writer.Close()
    $icoStream.Close()

    # Clean up
    $graphics.Dispose()
    $brush.Dispose()
    $textBrush.Dispose()
    $bitmap.Dispose()

    Write-Host "Icon created successfully at: $iconPath" -ForegroundColor Green
} catch {
    Write-Host "Error creating icon: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
