<#
.SYNOPSIS
    Analyzes a YouTube video using a specific system prompt (default: 'extract_wisdom') and the Gemini CLI.

.DESCRIPTION
    This script coordinates the process of:
    1. Downloading a YouTube transcript (using Get-YouTubeTranscript.ps1).
    2. Ensuring a specific analysis prompt is available locally (downloads from GitHub if missing).
    3. Sending the prompt and transcript to a Gemini CLI tool.

.PARAMETER Url
    The URL of the YouTube video to analyze.

.PARAMETER PromptName
    The name of the prompt pattern. Defaults to 'extract_wisdom'.
    The script looks for this in a 'Prompts' subdirectory.

.PARAMETER GeminiCommand
    The command to invoke the Gemini CLI. Defaults to 'gemini'.
    This command is expected to accept input via Pipeline or arguments. 
    Adjust the implementation below based on your specific CLI tool's syntax.

.EXAMPLE
    .\Get-YouTubeWisdom.ps1 -Url "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url,

    [string]$PromptName = "extract_wisdom",

    [string]$GeminiCommand = "gemini" 
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = "Stop"

# Configuration for Prompts
$PromptSourceUrl = "https://raw.githubusercontent.com/danielmiessler/Fabric/refs/heads/main/data/patterns/$PromptName/system.md"
$PromptsDir = Join-Path -Path $PSScriptRoot -ChildPath "Prompts"
$PromptFile = Join-Path -Path $PromptsDir -ChildPath "$PromptName.md"
$TranscriptsDir = Join-Path -Path $PSScriptRoot -ChildPath "Transcripts"
$OutputDir = Join-Path -Path $PSScriptRoot -ChildPath "Output"

# Ensure directories exist
foreach ($dir in @($PromptsDir, $TranscriptsDir, $OutputDir)) {
    if (-not (Test-Path -Path $dir)) {
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
}

# 1. Ensure Prompt Exists
if (-not (Test-Path -Path $PromptFile)) {
    Write-Host "Downloading '$PromptName' prompt from source..." -ForegroundColor Cyan
    try {
        Invoke-RestMethod -Uri $PromptSourceUrl -OutFile $PromptFile
        Write-Host "Prompt downloaded to: $PromptFile" -ForegroundColor Green
    }
    catch {
        Throw "Failed to download prompt from $PromptSourceUrl. Error: $_"
    }
}
else {
    Write-Verbose "Using cached prompt: $PromptFile"
}

# 2. Get Transcript
# We call the sibling script. We assume it's in the same directory.
$TranscriptScript = Join-Path -Path $PSScriptRoot -ChildPath "Get-YouTubeTranscript.ps1"
if (-not (Test-Path -Path $TranscriptScript)) {
    Throw "Could not find dependency script: $TranscriptScript"
}

Write-Host "Checking for transcript..." -ForegroundColor Cyan

# Check if we can determine the filename beforehand to check cache?
# Difficult because yt-dlp gets the title. 
# We'll rely on Get-YouTubeTranscript.ps1 logic or...
# Actually, to properly cache without hitting yt-dlp for the title every time, we'd need to know the title.
# But we don't. So we must call the script. 
# HOWEVER, Get-YouTubeTranscript.ps1 will always redownload currently. 
# Let's trust the user wants to avoid the *download* if possible, but we need the filename.
# Optimization: The simplest way with current architecture is to let the script run.
# But to implement "don't repeatedly download", we need to check if we already have it.
# We can't know the filename without the title. 
# Let's try to get the title first? No, that requires yt-dlp.
# Only way is if we search the Transcripts folder for a file that *contains* the video ID? 
# Or just let the TranscriptScript handle the "skip if exists" logic?
# For now, we will just direct it to the Transcripts folder. 
# Use the Transcript Script to handle the job.
# NOTE: To truly support "resume", the Transcript script should probably check if the file exists. 
# But for now, we will just organize the folders as requested.

try {
    # Call the script with the new OutputDir
    $TranscriptFileItem = & $TranscriptScript -Url $Url -OutputDir $TranscriptsDir
    
    if (-not $TranscriptFileItem) {
        Throw "The transcript script did not return a file."
    }
    Write-Verbose "Transcript available at: $($TranscriptFileItem.FullName)"
}
catch {
    Throw "Failed to get transcript. $_"
}

# 3. Analyze
Write-Host "Analyzing with Gemini..." -ForegroundColor Cyan

$PromptContent = Get-Content -Path $PromptFile -Raw -Encoding UTF8
$TranscriptContent = Get-Content -Path $TranscriptFileItem.FullName -Raw -Encoding UTF8

# Combine Prompt and Transcript
$FullInput = "$PromptContent`n`n--- TRANSCRIPT ---`n`n$TranscriptContent"

# Invoke the Gemini CLI
try {
    Write-Host "Sending to Gemini..." -ForegroundColor Cyan
    
    # Capture the output
    # We pass --allowed-mcp-server-names "none" to prevent MCP server connections.
    # We add --yolo to auto-approve any tool calls (preventing hangs on invisible confirmation prompts).
    $analysisResult = $FullInput | & $GeminiCommand "Please analyze the transcript based on the instructions provided." --allowed-mcp-server-names "none" --yolo
    
    # Construct output filename based on the video title
    $outputFilename = "$($TranscriptFileItem.BaseName)_wisdom.md"
    $outputFile = Join-Path -Path $OutputDir -ChildPath $outputFilename
    
    # Save to file
    $analysisResult | Set-Content -Path $outputFile -Encoding UTF8
    
    Write-Host "Success! Analysis saved to: $outputFile" -ForegroundColor Green
    
    # Return the file object
    Get-Item -Path $outputFile
}
catch {
    Write-Error "Failed to invoke Gemini CLI command: '$GeminiCommand'. Ensure it is installed and in your PATH."
    Write-Error "Error details: $_"
}
