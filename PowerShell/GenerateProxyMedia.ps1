[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [int]$MaxWidth = 1280
)

$exts = @(".mov", ".mp4", ".mxf", ".mkv", ".braw", ".r3d", ".ari", ".mts", ".m2ts", ".avi")

# Detect GPU encoder (NVENC > QSV > AMF)
$gpu = $null
if ((ffmpeg -hide_banner -encoders 2>$null | Select-String "h264_nvenc")) { $gpu = "h264_nvenc" }
elseif ((ffmpeg -hide_banner -encoders 2>$null | Select-String "h264_qsv")) { $gpu = "h264_qsv" }
elseif ((ffmpeg -hide_banner -encoders 2>$null | Select-String "h264_amf")) { $gpu = "h264_amf" }

if ($gpu) { Write-Host "Using GPU encoder: $gpu" }
else { Write-Host "Using CPU encoder (libx264)" }

Get-ChildItem -Path $Root -Recurse -File |
    Where-Object { ($exts -contains $_.Extension.ToLower()) -and ($_.DirectoryName -notmatch '\\Proxy($|\\)') } |
    ForEach-Object {
        $proxyDir = Join-Path $_.Directory.FullName "Proxy"
        $proxyPath = Join-Path $proxyDir "$($_.BaseName).mov"

        if (-not (Test-Path $proxyDir)) { New-Item -ItemType Directory -Path $proxyDir | Out-Null }
        if (Test-Path $proxyPath) { Write-Host "SKIP: $proxyPath"; return }

        $hasVideo = ffprobe -v error -select_streams v:0 -show_entries stream=index -of csv=p=0 $_.FullName 2>$null
        if (-not $hasVideo) { Write-Host "SKIP (no video): $($_.Name)"; return }

        Write-Host "ENCODING: $($_.FullName)"

        if ($gpu) {
            # GPU encoding - Matched to Blackmagic Proxy Generator settings
            $ffmpegCmd = "ffmpeg -y -hwaccel auto -i `"$($_.FullName)`" -vf `"scale='min($MaxWidth,iw)':'-2'`" -map 0:V:0 -map 0:a? -c:v $gpu -profile:v main -level 4.0 -b:v 2M -maxrate 2.5M -bufsize 4M -pix_fmt yuv420p -g 30 -bf 3 -c:a aac -b:a 320k -ac 2 -map_metadata 0 -copyts -vsync cfr -movflags +faststart `"$proxyPath`""
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
                Invoke-Expression $ffmpegCmd
            } else {
                Invoke-Expression "$ffmpegCmd 2>`$null"
            }
        } else {
            # CPU fallback - Matched to Blackmagic Proxy Generator settings
            $ffmpegCmd = "ffmpeg -y -i `"$($_.FullName)`" -vf `"scale='min($MaxWidth,iw)':'-2'`" -map 0:V:0 -map 0:a? -c:v libx264 -profile:v main -level 4.0 -b:v 2M -maxrate 2.5M -bufsize 4M -pix_fmt yuv420p -g 30 -bf 3 -preset medium -c:a aac -b:a 320k -ac 2 -map_metadata 0 -copyts -vsync cfr -movflags +faststart `"$proxyPath`""
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
                Invoke-Expression $ffmpegCmd
            } else {
                Invoke-Expression "$ffmpegCmd 2>`$null"
            }
        }
    }

Write-Host "`nDone!"