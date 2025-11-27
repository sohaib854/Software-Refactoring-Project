# PowerShell Script to Analyze Refactoring Data from JSON Files
# Generates a CSV report similar to the screenshot

# Parameters
param(
    [string]$InputPath = ".",
    [string]$OutputFile = "refactoring_report.csv",
    [int]$TopN = 10
)

# Function to categorize file into window (W1 or W2)
function Get-Window {
    param([string]$FileName)
    
    if ($FileName -match "1_10_13_before" -or $FileName -match "1_10_13_after") {
        return "W1"
    }
    elseif ($FileName -match "1_10_14") {
        return "W2"
    }
    return "Unknown"
}

# Initialize hashtable to store refactoring counts
$refactoringCounts = @{}
$totalRefactorings = 0

# Get all JSON files
$jsonFiles = Get-ChildItem -Path $InputPath -Filter "*.json" | Where-Object { $_.Name -match "refactorings_" }

Write-Host "Found $($jsonFiles.Count) JSON files to process"

# Process each JSON file
foreach ($file in $jsonFiles) {
    Write-Host "Processing: $($file.Name)"
    
    # Read and parse JSON
    $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
    $window = Get-Window -FileName $file.Name
    
    # Process commits
    foreach ($commit in $jsonContent.commits) {
        foreach ($refactoring in $commit.refactorings) {
            $refType = $refactoring.type
            
            # Initialize if not exists
            if (-not $refactoringCounts.ContainsKey($refType)) {
                $refactoringCounts[$refType] = @{
                    W1 = 0
                    W2 = 0
                }
            }
            
            # Increment count for the appropriate window
            $refactoringCounts[$refType][$window]++
            $totalRefactorings++
        }
    }
}

Write-Host "Total refactorings found: $totalRefactorings"

# Calculate totals and percentages
$results = @()
foreach ($refType in $refactoringCounts.Keys) {
    $w1Count = $refactoringCounts[$refType].W1
    $w2Count = $refactoringCounts[$refType].W2
    $total = $w1Count + $w2Count
    
    if ($totalRefactorings -gt 0) {
        $percentage = [math]::Round(($total / $totalRefactorings) * 100, 2)
    } else {
        $percentage = 0
    }
    
    $results += [PSCustomObject]@{
        "Refactoring Type" = $refType
        "W1" = $w1Count
        "W2" = $w2Count
        "Total" = $total
        "% of Total" = $percentage
    }
}

# Sort by total (descending) and take top N
$topResults = $results | Sort-Object -Property Total -Descending | Select-Object -First $TopN

# Export to CSV
$topResults | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host ""
Write-Host "Apache Ant - Top $TopN Refactoring Types"
Write-Host "==========================================="
$topResults | Format-Table -AutoSize

Write-Host ""
Write-Host "CSV file saved to: $OutputFile"
