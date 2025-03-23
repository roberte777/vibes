# PowerShell script to copy level files to LÖVE save directory

# Define source and destination paths
$sourceDir = ".\levels\default"
$destDir = "C:\Users\Ethan\AppData\Roaming\LOVE\vibes\levels\default"

# Create destination directory if it doesn't exist
if (-not (Test-Path $destDir)) {
    Write-Host "Creating destination directory: $destDir"
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
} else {
    # Remove all existing files from the destination directory
    Write-Host "Cleaning destination directory: $destDir"
    Get-ChildItem -Path $destDir -File | Remove-Item -Force
    Write-Host "Destination directory cleaned."
}

# Check if source directory exists
if (-not (Test-Path $sourceDir)) {
    Write-Host "Error: Source directory does not exist: $sourceDir" -ForegroundColor Red
    exit 1
}

# Copy all JSON files
Write-Host "Copying level files from $sourceDir to $destDir"
$files = Get-ChildItem -Path $sourceDir -Filter "*.json"

if ($files.Count -eq 0) {
    Write-Host "No JSON files found in source directory." -ForegroundColor Yellow
} else {
    foreach ($file in $files) {
        Write-Host "Copying $($file.Name)..."
        Copy-Item -Path $file.FullName -Destination $destDir -Force
    }
    Write-Host "Successfully copied $($files.Count) level files." -ForegroundColor Green
}# PowerShell script to copy level files to LÖVE save directory