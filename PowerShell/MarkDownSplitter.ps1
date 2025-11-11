# Path to your large markdown file
$largeMarkdownFile = "path\to\your\large\markdownfile.md"

# Directory where you want to save the individual markdown files
$outputDir = "path\to\output\directory"

# List of headings that represent the breaks in the large markdown file
$headings = @(
    "Project Dawn Intro",
    "Pay 360 Intro",
    "Red Gate View",
    "Computacenter first call",
    "SQL Instance review process",
    "Jon and Luke",
    "Dan first call",
    "Procure Wizard Intro",
    "Luke - SQL Versions, Patching, RCSI",
    "Replication Cleanup Incident",
    "RML Utility",
    "Replication demo",
    "Ion",
    "Richard Bowen - Missing Indexes",
    "Acteol Intro",
    "Acteol First Meeting",
    "Q1 Scope",
    "ProcureWizard Report",
    "Acteol P1 2024-08-06",
    "Petru",
    "Zoltan(AWS)",
    "Luke Extension",
    "Tom Licensing Cloud Engineer",
    "Neil Meeting Extension",
    "Pay360 EOD Files not there",
    "Adam Roberts Call",
    "Standups"
)

# Read the entire content of the large markdown file
$markdownContent = Get-Content -Path $largeMarkdownFile -Raw

# Loop through each heading to split the content
for ($i = 0; $i -lt $headings.Count; $i++) {
    $currentHeading = $headings[$i]

    # Find the start index of the current heading
    $startIndex = $markdownContent.IndexOf($currentHeading)

    # Determine the end index of the current section (start of the next heading or end of document)
    if ($i -lt $headings.Count - 1) {
        $nextHeading = $headings[$i + 1]
        $endIndex = $markdownContent.IndexOf($nextHeading)
    } else {
        # For the last heading, grab until the end of the document
        $endIndex = $markdownContent.Length
    }

    # Ensure indices are valid and extract content
    if ($startIndex -ge 0) {
        if ($endIndex -le $startIndex) {
            $endIndex = $markdownContent.Length
        }

        # Extract content for the current section
        $sectionContent = $markdownContent.Substring($startIndex, $endIndex - $startIndex).Trim()

        # Create the new markdown file with the heading as the filename
        $outputFile = Join-Path $outputDir ("$currentHeading.md")

        # Write the content to the new file
        Set-Content -Path $outputFile -Value $sectionContent

        Write-Host "Created $outputFile with content length: $($sectionContent.Length)"

        # Delay to ensure file timestamps differ
        Start-Sleep -Milliseconds 500
    } else {
        Write-Host "No content found for $currentHeading"
    }
}
