param (
    [Parameter(Mandatory = $true)]
    [string]$folderPath,

    [Parameter(Mandatory = $false)]
    [bool]$enableDebug = $true
)

# Function to invoke MarkdownLint
function Invoke-MarkdownLint {
    param (
        [string]$filePath
    )

    # Check if markdownlint is installed
    $markdownlint = Get-Command markdownlint -ErrorAction SilentlyContinue
    if (-not $markdownlint) {
        Write-Warning "markdownlint is not installed. Skipping linting for ${filePath}."
        return
    }

    # Run markdownlint on the file
    try {
        $lintResult = markdownlint $filePath
        if ($lintResult) {
            Write-Warning "MarkdownLint issues found in ${filePath}:"
            Write-Output $lintResult
        }
        else {
            Write-Output "No MarkdownLint issues found in ${filePath}."
        }
    }
    catch {
        Write-Error "Failed to run markdownlint on ${filePath}: $_"
    }
}

# Validate the folder path
if (-not (Test-Path -Path $folderPath)) {
    Write-Error "The specified folder path does not exist: ${folderPath}"
    exit 1
}

# Define the path to the test folder if debug is enabled
$testFolderPath = Join-Path -Path $folderPath -ChildPath "test"

# If debug is enabled, create the test folder if it doesn't exist
if ($enableDebug) {
    if (-not (Test-Path -Path $testFolderPath)) {
        try {
            New-Item -Path $testFolderPath -ItemType Directory -Force | Out-Null
            Write-Output "Created test folder at: ${testFolderPath}"
        }
        catch {
            Write-Error "Failed to create test folder: $_"
            exit 1
        }
    }
}

# Get all Markdown files in the specified folder
Get-ChildItem -Path $folderPath -Filter *.md | ForEach-Object {
    $file = $_.FullName
    Write-Output "Processing file: ${file}"

    # Read all lines from the current Markdown file
    $lines = Get-Content -Path $file

    # Initialize an array to hold the modified lines
    $newLines = @()

    # State variables to track front matter, code blocks, and tables
    $inFrontMatter = $false
    $inCodeBlock = $false
    $inTable = $false

    # Iterate through each line by index
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $currentLine = $lines[$i]
        $trimmedLine = $currentLine.Trim()

        # If the current line is entirely blank, add it and skip further processing
        if ($trimmedLine -eq '') {
            $newLines += $currentLine
            continue
        }

        # Check for front matter start/end
        if ($trimmedLine -eq '---') {
            $inFrontMatter = -not $inFrontMatter
            $newLines += $currentLine
            continue
        }

        # Check for code block start/end
        if ($trimmedLine -match '^```') {
            $inCodeBlock = -not $inCodeBlock
            $newLines += $currentLine
            continue
        }

        # If inside front matter or code block, add the line as-is
        if ($inFrontMatter -or $inCodeBlock) {
            $newLines += $currentLine
            continue
        }

        # Check if the line is a list item (bullet or numbered)
        if ($trimmedLine -match '^([-*+]\s|(\d+\.\s))') {
            $newLines += $currentLine
            continue
        }

        # Check for table start
        if (-not $inTable -and $trimmedLine -match '^\|') {
            # Peek the next line to check for table delimiter
            if ($i + 1 -lt $lines.Count) {
                $nextLine = $lines[$i + 1].Trim()
                if ($nextLine -match '^\|?\s*(:?-{3,}:?\s*\|)+\s*$') {
                    $inTable = $true
                }
            }
        }

        # If currently inside a table, add the line as-is
        if ($inTable) {
            $newLines += $currentLine
            # Check if the next line is not part of the table
            if ($i + 1 -lt $lines.Count) {
                $nextLine = $lines[$i + 1].Trim()
                if (-not $nextLine -match '^\|') {
                    $inTable = $false
                }
            }
            else {
                # Last line, exit table
                $inTable = $false
            }
            continue
        }

        # Add the current line to the newLines array
        $newLines += $currentLine

        # Check if not the last line to avoid index out of range
        if ($i -lt ($lines.Count - 1)) {
            $nextLine = $lines[$i + 1]
            $nextTrimmed = $nextLine.Trim()

            # If the next line is already blank, do not add another blank line
            if ($nextTrimmed -eq '') {
                continue
            }

            # Determine if current or next line does NOT start with '#'
            $currentTrimmed = $currentLine.TrimStart()
            $shouldAddBlankLine = (-not $currentTrimmed.StartsWith('#')) -or (-not $nextTrimmed.StartsWith('#'))

            # Add a blank line if conditions are met and the next line is not already blank
            if ($shouldAddBlankLine) {
                $newLines += ''  # Add a blank line
            }
        }
    }

    # Determine the output path based on the debug flag
    if ($enableDebug) {
        $relativePath = $_.Name  # Get the file name
        $outputPath = Join-Path -Path $testFolderPath -ChildPath $relativePath
    }
    else {
        $outputPath = $file  # Overwrite the original file
    }

    # Optionally, create a backup of the original file when not in debug mode
    if (-not $enableDebug) {
        $backupPath = "${file}.bak"
        if (-not (Test-Path -Path $backupPath)) {
            try {
                Copy-Item -Path $file -Destination $backupPath -Force
                Write-Output "Backup created: ${backupPath}"
            }
            catch {
                Write-Error "Failed to create backup for ${file}: $_"
                continue
            }
        }
    }

    # Write the modified lines to the appropriate output path
    try {
        $newLines | Set-Content -Path $outputPath -Encoding UTF8
        Write-Output "Finished processing file: ${outputPath}`n"

        # Invoke MarkdownLint
        Invoke-MarkdownLint -filePath $outputPath
    }
    catch {
        Write-Error "Failed to write to ${outputPath}: $_"
    }
}

Write-Output "All Markdown files have been processed."
