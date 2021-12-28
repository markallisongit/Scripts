$Path = "F:\Videos\GoPro\Raw\2021\2021-12-21 Awesome shortest day"
$Path = "F:\Videos\GoPro\Raw\2021\2021-12-24 Christmas Eve to LG"
$Path = "F:\Videos\GoPro\Raw\2021"
Get-ChildItem -Path "$Path\*.H265.mp4" -Recurse | Rename-Item -NewName {$_.Name -replace ".H265",''} -WhatIf