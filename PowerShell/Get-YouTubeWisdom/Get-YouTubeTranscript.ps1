<#
.SYNOPSIS
    Downloads and extracts the transcript from a YouTube video as a text file.

.DESCRIPTION
    This script uses yt-dlp to download the subtitles (manual or auto-generated) for a given YouTube video.
    It then processes the VTT file to remove timestamps and formatting, saving the plain text transcript
    to the same directory as the script, named after the video title.

.PARAMETER Url
    The URL of the YouTube video to process.

.PARAMETER YtDlpPath
    The path to the yt-dlp executable. Defaults to 'C:\Tools\yt-dlp'.
    If the specific file is not found, the script checks the system PATH.

.EXAMPLE
    .\Get-YouTubeTranscript.ps1 -Url "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url,

    [Parameter(Position = 1)]
    [string]$YtDlpPath = "C:\Tools\yt-dlp",

    [string]$OutputDir = $PSScriptRoot
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Ensure OutputDir exists
if (-not (Test-Path -Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory | Out-Null
}

# 1. Resolve yt-dlp path
if (-not (Test-Path -Path $YtDlpPath -PathType Leaf)) {
    # Check if 'yt-dlp.exe' exists at the path (if extension was omitted)
    if (Test-Path -Path "$YtDlpPath.exe" -PathType Leaf) {
        $YtDlpPath = "$YtDlpPath.exe"
    }
    else {
        # Try finding in PATH
        $command = Get-Command -Name "yt-dlp" -ErrorAction SilentlyContinue
        if ($command) {
            $YtDlpPath = $command.Source
            Write-Verbose "Using yt-dlp found in PATH: $YtDlpPath"
        }
        else {
            Throw "yt-dlp not found at '$YtDlpPath' and not in system PATH."
        }
    }
}

# 2. Get Video Title
Write-Host "Fetching video information..." -ForegroundColor Cyan
try {
    # output template needs to be sanitized for filename usage by yt-dlp logic, 
    # but we will just ask for the title string and sanitize it ourselves for the PS filesystem.
    $title = & $YtDlpPath --print filename -o "%(title)s" "$Url" 2>$null
    
    if (-not $title) {
        Throw "Could not retrieve video title."
    }
    
    # Sanitize title for filename
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    $pattern = "[{0}]" -f [regex]::Escape([string]::new($invalidChars))
    $cleanTitle = $title -replace $pattern, ''
    $cleanTitle = $cleanTitle.Trim()

    # Check for existing file to avoid re-downloading
    $potentialFile = Join-Path -Path $OutputDir -ChildPath "$cleanTitle.txt"
    if (Test-Path -Path $potentialFile) {
        Write-Host "Transcript already exists. Skipping download." -ForegroundColor Green
        return (Get-Item -Path $potentialFile)
    }
}
catch {
    Throw "Failed to get video info. Ensure URL is valid and yt-dlp is working. Details: $_"
}

Write-Host "Video Title: $title" -ForegroundColor Green

# 3. Download Subtitles (VTT)
$tempBaseName = "tmp_transcript_$(New-Guid)"
$tempFilePattern = Join-Path -Path $PSScriptRoot -ChildPath "$tempBaseName*"

Write-Host "Downloading subtitles..." -ForegroundColor Cyan

# Flags:
# --write-sub: Write subtitle file
# --write-auto-sub: Write automatically generated subtitle file (fallback)
# --sub-lang en: English
# --sub-format vtt: WebVTT format
# --skip-download: Don't download video
# --output: Temp filename pattern
$outputPathTemplate = Join-Path -Path $PSScriptRoot -ChildPath $tempBaseName
$process = Start-Process -FilePath $YtDlpPath -ArgumentList "--write-sub", "--write-auto-sub", "--sub-lang", "en", "--sub-format", "vtt", "--skip-download", "--output", "$outputPathTemplate", "$Url" -NoNewWindow -PassThru -Wait

if ($process.ExitCode -ne 0) {
    Throw "yt-dlp failed with exit code $($process.ExitCode)"
}

# Find the resulting file (could be .en.vtt, .vtt, etc.)
$vttFile = Get-ChildItem -Path $tempFilePattern -Filter "*.vtt" | Select-Object -First 1

if (-not $vttFile) {
    Throw "No transcript found (English). The video might not have subtitles/captions."
}

# 4. Process VTT to Text
Write-Host "Processing transcript..." -ForegroundColor Cyan

$content = Get-Content -Path $vttFile.FullName -Encoding UTF8
$cleanLines = @()
$seenLines = [System.Collections.Generic.HashSet[string]]::new()

foreach ($line in $content) {
    $trimLine = $line.Trim()

    # Skip empty lines, 'WEBVTT' header, and timestamp lines
    if ([string]::IsNullOrWhiteSpace($trimLine) -or 
        $trimLine -eq "WEBVTT" -or 
        $trimLine.StartsWith("Kind:") -or 
        $trimLine.StartsWith("Language:") -or
        $trimLine -match '^\d{2}:\d{2}:\d{2}\.\d{3} --> \d{2}:\d{2}:\d{2}\.\d{3}') {
        continue
    }

    # Skip purely numeric lines (sometimes index numbers) or simple formatting noise
    if ($trimLine -match '^\d+$') { continue }

    # Remove basic XML/HTML tags if present (e.g. <c>, <00:00:00>)
    $textOnly = $trimLine -replace '<[^>]+>', ''

    # Deduplicate consecutive lines (common in some caption formats)
    # Using a simple check against the last added line or a generic dedupe?
    # Captions often repeat phrases. We'll do simple consecutive dedupe + global checking if strict
    # but for transcripts, usually just consecutive dedupe is safer to avoid removing refrains in songs etc.
    # However, strict 'seen' set is better for auto-generated rolling captions.
    
    if (-not [string]::IsNullOrWhiteSpace($textOnly)) {
        # Check if line contains text already seen recently? 
        # Simple approach: If the line is exactly the same as the previous one, skip.
        if ($cleanLines.Count -eq 0 -or $cleanLines[-1] -ne $textOnly) {
            $cleanLines += $textOnly
        }
    }
}

# 5. Save Output
$outputFile = Join-Path -Path $OutputDir -ChildPath "$cleanTitle.txt"
$cleanLines | Set-Content -Path $outputFile -Encoding UTF8

# 6. Cleanup
Remove-Item -Path $vttFile.FullName -Force

Write-Verbose "Success! Transcript saved to: $outputFile"
# Return the file object so other scripts can consume it
Get-Item -Path $outputFile
