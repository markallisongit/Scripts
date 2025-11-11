# Spotify Library Export - Simple Token Method
# This method uses a token from Spotify Web Player (easier setup)

# Instructions to get your token:
# 1. Go to https://open.spotify.com in your browser
# 2. Open Developer Tools (F12)
# 3. Go to Network tab
# 4. Refresh the page or navigate to Your Library > Albums
# 5. Look for requests to api.spotify.com
# 6. Find the Authorization header that starts with "Bearer "
# 7. Copy the token (everything after "Bearer ")
param (
    $AccessToken
)

# Function to get saved albums
function Get-SpotifyAlbums {
    param([string]$AccessToken)
    
    $Headers = @{
        "Authorization" = "Bearer $AccessToken"
    }
    
    $Albums = @()
    $Offset = 0
    $Limit = 50
    
    do {
        try {
            $Url = "https://api.spotify.com/v1/me/albums?limit=$Limit&offset=$Offset"
            $Response = Invoke-RestMethod -Uri $Url -Headers $Headers
            
            foreach ($Item in $Response.items) {
                $Album = $Item.album
                $Albums += [PSCustomObject]@{
                    AlbumName = $Album.name
                    ArtistName = ($Album.artists | ForEach-Object { $_.name }) -join ", "
                    ReleaseDate = $Album.release_date
                    TotalTracks = $Album.total_tracks
                    AlbumType = $Album.album_type
                    SpotifyUrl = $Album.external_urls.spotify
                    AddedAt = $Item.added_at
                    Genres = ($Album.genres -join ", ")
                    Popularity = $Album.popularity
                }
            }
            
            $Offset += $Limit
            Write-Host "Retrieved $($Albums.Count) albums so far..." -ForegroundColor Green
            
        } catch {
            Write-Error "Error retrieving albums: $($_.Exception.Message)"
            break
        }
        
    } while ($Response.items.Count -eq $Limit)
    
    return $Albums
}

# Main execution
try {
    Write-Host "Spotify Library Export Tool (Simple Method)" -ForegroundColor Green
    Write-Host "===========================================" -ForegroundColor Green
    
    # Test the token first
    Write-Host "Testing access token..." -ForegroundColor Yellow
    $TestHeaders = @{ "Authorization" = "Bearer $AccessToken" }
    $TestResponse = Invoke-RestMethod -Uri "https://api.spotify.com/v1/me" -Headers $TestHeaders
    Write-Host "Token is valid! Hello, $($TestResponse.display_name)!" -ForegroundColor Green
    
    # Get albums
    Write-Host "Retrieving your saved albums..." -ForegroundColor Yellow
    $Albums = Get-SpotifyAlbums -AccessToken $AccessToken
    
    if ($Albums.Count -eq 0) {
        Write-Host "No albums found in your library." -ForegroundColor Yellow
        return
    }
    
    # Export to CSV
    $OutputFile = "SpotifyAlbums_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $Albums | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
    
    Write-Host ""
    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Found $($Albums.Count) albums in your library"
    Write-Host "Exported to: $OutputFile"
    
    # Display first few albums as preview
    Write-Host ""
    Write-Host "Preview of first 5 albums:" -ForegroundColor Yellow
    $Albums | Select-Object -First 5 | Format-Table AlbumName, ArtistName, ReleaseDate -AutoSize
    
    # Show file location
    $FullPath = (Get-Location).Path + "\" + $OutputFile
    Write-Host ""
    Write-Host "Full file path: $FullPath" -ForegroundColor Cyan
    
} catch {
    Write-Error "Error: $($_.Exception.Message)"
    
    if ($_.Exception.Message -like "*401*" -or $_.Exception.Message -like "*Unauthorized*") {
        Write-Host ""
        Write-Host "Your access token has expired. Please get a new one following the instructions above." -ForegroundColor Red
    }
}