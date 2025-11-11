#Requires -Version 7.0
<#
.SYNOPSIS
    Bulk update YouTube video descriptions using the YouTube Data API
.DESCRIPTION
    Updates video descriptions across your channel by replacing old text with new text.
    Requires YouTube API credentials (OAuth 2.0).
.PARAMETER OldText
    The text to find and replace (default: original stats page URL)
.PARAMETER NewText
    The replacement text (default: new stats page URL)
.PARAMETER DryRun
    Preview changes without actually updating (default: $true)
.PARAMETER CredentialsPath
    Path to credentials.json file (default: current directory)
#>

param(
    [string]$OldText = "https://ppgstats.markallison.co.uk/",
    [string]$NewText = "https://tinyurl.com/marksppgstats",
    [switch]$Apply,
    [string]$CredentialsPath = "credentials.json",
    [string]$ChannelId = "",
    [int]$Limit = 0
)

$DryRun = -not $Apply

# Configuration
$apiUrl = "https://www.googleapis.com/youtube/v3"
$tokenFile = "youtube_token.json"
$maxResults = 50

# ============================================================================
# FUNCTIONS
# ============================================================================

function Get-AuthToken {
    param([string]$CredPath)

    if (-not (Test-Path $CredPath)) {
        Write-Error "credentials.json not found at $CredPath"
        Write-Host ""
        Write-Host "Setup instructions:"
        Write-Host "1. Go to: https://console.cloud.google.com"
        Write-Host "2. Create a new project"
        Write-Host "3. Enable YouTube Data API v3"
        Write-Host "4. Create OAuth 2.0 Desktop app credentials"
        Write-Host "5. Download as JSON and save as credentials.json"
        Write-Host ""
        exit 1
    }

    # Check if we have a cached token
    if (Test-Path $tokenFile) {
        $token = Get-Content $tokenFile | ConvertFrom-Json
        if ($token.expires_at -gt [DateTime]::UtcNow.AddMinutes(5)) {
            Write-Host "✓ Using cached access token"
            return $token.access_token
        }
        # Token expired, try to refresh
        if ($token.refresh_token) {
            return Refresh-AuthToken $token.refresh_token
        }
    }

    # Need new auth - open browser for OAuth flow
    Write-Host "Opening browser for authentication..."
    $creds = Get-Content $CredPath | ConvertFrom-Json

    $clientId = $creds.installed.client_id
    $clientSecret = $creds.installed.client_secret
    $redirectUri = "http://localhost:8888"

    $authUrl = @(
        "https://accounts.google.com/o/oauth2/v2/auth"
        "?client_id=$clientId"
        "&redirect_uri=$redirectUri"
        "&response_type=code"
        "&scope=https://www.googleapis.com/auth/youtube"
    ) -join ""

    # Try to open browser, fall back to manual URL if WSL
    try {
        Start-Process $authUrl -ErrorAction Stop
    }
    catch {
        Write-Host ""
        Write-Host "MANUAL AUTH REQUIRED (WSL detected)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Copy this URL into your Windows browser:" -ForegroundColor Cyan
        Write-Host "$authUrl"
        Write-Host ""
    }

    # Simple local server to capture auth code
    Write-Host "Waiting for authentication (check your browser)..."
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add($redirectUri + "/")
    $listener.Start()

    $context = $listener.GetContext()
    $request = $context.Request
    $code = $request.QueryString["code"]

    # Send response to browser
    $response = $context.Response
    $response.StatusCode = 200
    $buffer = [System.Text.Encoding]::UTF8.GetBytes("Authorization successful! You can close this window.")
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()

    $listener.Stop()

    if (-not $code) {
        Write-Error "Failed to get authorization code"
        exit 1
    }

    # Exchange code for tokens
    $tokenResponse = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        client_id     = $clientId
        client_secret = $clientSecret
        code          = $code
        grant_type    = "authorization_code"
        redirect_uri  = $redirectUri
    }

    # Save token with expiry
    $tokenObject = @{
        access_token  = $tokenResponse.access_token
        refresh_token = $tokenResponse.refresh_token
        expires_at    = ([DateTime]::UtcNow).AddSeconds($tokenResponse.expires_in)
    }

    $tokenObject | ConvertTo-Json | Set-Content $tokenFile
    Write-Host "✓ Authentication successful"

    return $tokenResponse.access_token
}

function Refresh-AuthToken {
    param([string]$RefreshToken)

    $creds = Get-Content $CredentialsPath | ConvertFrom-Json

    $tokenResponse = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method Post -Body @{
        client_id     = $creds.installed.client_id
        client_secret = $creds.installed.client_secret
        refresh_token = $RefreshToken
        grant_type    = "refresh_token"
    }

    $tokenObject = @{
        access_token  = $tokenResponse.access_token
        refresh_token = $RefreshToken
        expires_at    = ([DateTime]::UtcNow).AddSeconds($tokenResponse.expires_in)
    }

    $tokenObject | ConvertTo-Json | Set-Content $tokenFile
    return $tokenResponse.access_token
}

function Get-MyChannels {
    param([string]$AccessToken)

    try {
        $params = @{
            Uri     = "$apiUrl/channels"
            Headers = @{ Authorization = "Bearer $AccessToken" }
            Body    = @{
                part    = "snippet,brandingSettings"
                mine    = "true"
                maxResults = 50
            }
        }

        $response = Invoke-RestMethod @params
        return $response.items
    }
    catch {
        Write-Host "Error fetching channels: $_" -ForegroundColor Red
        Write-Host "Response: $($_.Exception.Response)" -ForegroundColor Red
        throw
    }
}

function Get-ChannelVideos {
    param(
        [string]$AccessToken,
        [string]$ChannelId,
        [int]$MaxResults = 50,
        [string]$PageToken = ""
    )

    $params = @{
        Uri     = "$apiUrl/search"
        Headers = @{ Authorization = "Bearer $AccessToken" }
        Body    = @{
            part           = "snippet"
            channelId      = $ChannelId
            type           = "video"
            maxResults     = $MaxResults
            pageToken      = $PageToken
            order          = "date"
        }
    }

    $response = Invoke-RestMethod @params
    return $response
}

function Get-VideoDetails {
    param(
        [string]$AccessToken,
        [string[]]$VideoIds
    )

    $params = @{
        Uri     = "$apiUrl/videos"
        Headers = @{ Authorization = "Bearer $AccessToken" }
        Body    = @{
            part = "snippet,status,fileDetails"
            id   = ($VideoIds -join ",")
        }
    }

    $response = Invoke-RestMethod @params
    return $response.items
}

function Update-VideoDescription {
    param(
        [string]$AccessToken,
        [string]$VideoId,
        [string]$Title,
        [string]$NewDescription,
        [string]$CategoryId
    )

    $body = @{
        id      = $VideoId
        snippet = @{
            title       = $Title
            description = $NewDescription
            categoryId  = $CategoryId
        }
    } | ConvertTo-Json -Depth 10

    try {
        $response = Invoke-WebRequest -Uri "$apiUrl/videos?part=snippet" `
            -Headers @{
                Authorization  = "Bearer $AccessToken"
                "Content-Type" = "application/json"
            } `
            -Method Put `
            -Body $body
        return $true
    }
    catch {
        Write-Error "Failed to update $VideoId : $_"
        return $false
    }
}

# ============================================================================
# MAIN
# ============================================================================

Write-Host ""
Write-Host "YouTube Description Bulk Updater" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "MODE: DRY RUN (no changes will be made)" -ForegroundColor Yellow
}
else {
    Write-Host "MODE: LIVE UPDATE" -ForegroundColor Red
}

Write-Host ""
Write-Host "Find: $OldText" -ForegroundColor White
Write-Host "Replace with: $NewText" -ForegroundColor White
Write-Host ""

# Get auth token
$accessToken = Get-AuthToken -CredPath $CredentialsPath

# Get available channels
Write-Host "Fetching your channels..."
$channels = Get-MyChannels -AccessToken $accessToken

if ($channels.Count -eq 0) {
    Write-Error "No channels found"
    exit 1
}

# Select channel
if ($ChannelId -eq "") {
    Write-Host ""
    Write-Host "Available channels:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $channels.Count; $i++) {
        $channel = $channels[$i]
        Write-Host "  [$($i + 1)] $($channel.snippet.title) (ID: $($channel.id))"
    }

    if ($channels.Count -eq 1) {
        Write-Host ""
        Write-Host "Using: $($channels[0].snippet.title)"
        $selectedChannel = $channels[0]
    }
    else {
        Write-Host ""
        $choice = Read-Host "Select channel (1-$($channels.Count))"
        $selectedChannel = $channels[[int]$choice - 1]
    }
}
else {
    $selectedChannel = $channels | Where-Object { $_.id -eq $ChannelId }
    if (-not $selectedChannel) {
        Write-Error "Channel ID not found: $ChannelId"
        exit 1
    }
}

$selectedChannelId = $selectedChannel.id
Write-Host "✓ Using channel: $($selectedChannel.snippet.title)" -ForegroundColor Green
Write-Host ""

# Fetch all videos
Write-Host "Fetching videos from your channel..."
$allVideos = @()
$pageToken = ""
$totalVideos = 0

do {
    $result = Get-ChannelVideos -AccessToken $accessToken -ChannelId $selectedChannelId -PageToken $pageToken
    $allVideos += $result.items
    $totalVideos += $result.items.Count
    $pageToken = $result.nextPageToken

    Write-Host "  Downloaded: $totalVideos videos..."
} while ($pageToken)

Write-Host "✓ Found $totalVideos videos" -ForegroundColor Green
Write-Host ""

# Get full details for videos (need description field)
Write-Host "Fetching video details..."
$videoIds = @()
foreach ($video in $allVideos) {
    $videoIds += $video.id.videoId
}

$videosToUpdate = @()
$batchSize = 50

for ($i = 0; $i -lt $videoIds.Count; $i += $batchSize) {
    $batch = $videoIds[$i..($i + $batchSize - 1)]
    $details = Get-VideoDetails -AccessToken $accessToken -VideoIds $batch

    foreach ($video in $details) {
        if ($video.snippet.description -like "*$OldText*") {
            $videosToUpdate += $video
        }
    }
}

Write-Host "✓ Found $($videosToUpdate.Count) videos with text to replace" -ForegroundColor Green

if ($Limit -gt 0) {
    $videosToUpdate = $videosToUpdate[0..($Limit - 1)]
    Write-Host "⚠ Limited to first $Limit video(s)" -ForegroundColor Yellow
}

Write-Host ""

if ($videosToUpdate.Count -eq 0) {
    Write-Host "No videos found with the text to replace."
    exit 0
}

# Show preview
Write-Host "Videos to update:" -ForegroundColor Cyan
Write-Host ""

$updateCount = 0
foreach ($video in $videosToUpdate) {
    $newDesc = $video.snippet.description -replace [regex]::Escape($OldText), $NewText

    Write-Host "[$($updateCount + 1)] $($video.snippet.title)" -ForegroundColor White
    Write-Host "     URL: https://youtube.com/watch?v=$($video.id)"
    Write-Host ""

    if ($DryRun) {
        # Find the URL in the description to show context
        $beforeIdx = $video.snippet.description.IndexOf($OldText)
        if ($beforeIdx -ge 0) {
            $start = [Math]::Max(0, $beforeIdx - 20)
            $length = [Math]::Min(200, $video.snippet.description.Length - $start)
            $beforeSnippet = $video.snippet.description.Substring($start, $length)

            $afterSnippet = $newDesc.Substring($start, [Math]::Min(200, $newDesc.Length - $start))

            Write-Host "     BEFORE:" -ForegroundColor Gray
            Write-Host "     ...$beforeSnippet..."
            Write-Host ""
            Write-Host "     AFTER:" -ForegroundColor Green
            Write-Host "     ...$afterSnippet..."
            Write-Host ""
        }
    }

    $updateCount++
}

Write-Host ""
if ($DryRun) {
    Write-Host "DRY RUN COMPLETE - No changes made" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To apply these changes, run:" -ForegroundColor Cyan
    Write-Host "  .\Update-YouTubeDescriptions.ps1 -DryRun `$false"
    Write-Host ""
}
else {
    # Confirm before updating
    Write-Host "About to update $($videosToUpdate.Count) videos" -ForegroundColor Red
    $confirm = Read-Host "Continue? (yes/no)"

    if ($confirm -ne "yes") {
        Write-Host "Cancelled"
        exit 0
    }

    Write-Host ""
    Write-Host "Updating videos..." -ForegroundColor Cyan

    $successCount = 0
    $failCount = 0

    foreach ($video in $videosToUpdate) {
        $newDesc = $video.snippet.description -replace [regex]::Escape($OldText), $NewText

        if (Update-VideoDescription -AccessToken $accessToken -VideoId $video.id -Title $video.snippet.title -NewDescription $newDesc -CategoryId $video.snippet.categoryId) {
            Write-Host "✓ Updated: $($video.snippet.title)"
            $successCount++
        }
        else {
            Write-Host "✗ Failed: $($video.snippet.title)"
            $failCount++
        }
    }

    Write-Host ""
    Write-Host "COMPLETE" -ForegroundColor Green
    Write-Host "  Success: $successCount"
    Write-Host "  Failed: $failCount"
}
