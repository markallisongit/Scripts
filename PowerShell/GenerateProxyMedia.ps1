[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Root,
    [int]$MaxWidth = 1920
)
$exts = @(".mov", ".mp4", ".mxf", ".mkv", ".braw", ".r3d", ".ari", ".mts", ".m2ts", ".avi")
# ProRes has no GPU encode path, so the GPU only accelerates decoding of the source.
# Prefer CUDA over the D3D paths, which are less predictable with 10-bit HEVC.
$hwaccels = ffmpeg -hide_banner -hwaccels 2>$null
$hwaccel = $null
if ($hwaccels | Select-String -SimpleMatch "cuda") { $hwaccel = "cuda" }
elseif ($hwaccels | Select-String -SimpleMatch "qsv") { $hwaccel = "qsv" }
elseif ($hwaccels | Select-String -SimpleMatch "d3d11va") { $hwaccel = "d3d11va" }
if ($hwaccel) { Write-Host "Encoding ProRes 422 Proxy (CPU) using $hwaccel hardware decode" }
else { Write-Host "Encoding ProRes 422 Proxy (CPU) using software decode" }
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
    # ProRes 422 Proxy: intraframe, so Resolve scrubs it smoothly. prores_ks is
    # 10-bit only, which suits the 10-bit HEVC sources and keeps grading latitude.
    $decode = if ($hwaccel) { "-hwaccel $hwaccel " } else { "" }
    $ffmpegCmd = "ffmpeg -y $decode-i `"$($_.FullName)`" -vf `"scale='min($MaxWidth,iw)':'-2'`" -map 0:V:0 -map 0:a? -c:v prores_ks -profile:v proxy -pix_fmt yuv422p10le -c:a pcm_s16le -ac 2 -map_metadata 0 -copyts -vsync cfr -movflags +faststart `"$proxyPath`""
    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent) {
        Invoke-Expression $ffmpegCmd
    }
    else {
        Invoke-Expression "$ffmpegCmd 2>`$null"
    }
}
Write-Host "`nDone!"