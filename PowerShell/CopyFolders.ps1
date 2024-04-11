param(
    [string]$SourceFolder,
    [string]$DestinationFolder,
    [string]$FolderPrefix
)

# Check if source folder exists
if (-not (Test-Path $SourceFolder -PathType Container)) {
    throw "Source folder '$SourceFolder' not found."
}

# Create destination folder if it doesn't exist
if (-not (Test-Path $DestinationFolder -PathType Container)) {
    New-Item -ItemType Directory -Path $DestinationFolder | Out-Null
}

# Get list of subfolders in source folder that match the prefix
$Subfolders = Get-ChildItem -Path $SourceFolder -Directory | Where-Object { $_.Name -like "$FolderPrefix*" }

# Copy files using robocopy for each matching subfolder
foreach ($Subfolder in $Subfolders) {
    $SubfolderPath = Join-Path -Path $SourceFolder -ChildPath $Subfolder.Name
    $DestinationSubfolder = Join-Path -Path $DestinationFolder -ChildPath $Subfolder.Name
    $robocopyParams = @(
        $SubfolderPath,
        $DestinationSubfolder,
        "/e",
        "/mov",
        "/nfl",
        "/njh",
        "/ndl",
        "/r:5",
        "/w:5"
)

    # Run robocopy
    robocopy $robocopyParams
}
