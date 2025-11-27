# PowerShell Script to Analyze Refactoring Data from JSON Files
# Generates a CSV report with ALL refactoring types detected
#
# This script uses a predefined list of all known RefactoringMiner types and counts them.
# If new types are found that are not in the list, they are dynamically added.
#
# Source: https://github.com/tsantalis/RefactoringMiner

# Parameters
param(
    [string]$InputPath = ".",
    [string]$OutputFile = "refactoring_report.csv",
    [int]$TopN = 0,  # 0 = include ALL refactoring types, N > 0 = include only top N types
    [switch]$ExcludeZeroCounts  # If specified, exclude refactoring types with 0 counts
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

# Predefined list of ALL known RefactoringMiner types (as of November 2025)
$knownRefactoringTypes = @(
    "Extract Method",
    "Inline Method",
    "Rename Method",
    "Move Method",
    "Move And Rename Method",
    "Extract And Move Method",
    "Move And Inline Method",
    "Pull Up Method",
    "Push Down Method",
    "Merge Method",
    "Split Method",
    "Rename Class",
    "Move Class",
    "Move And Rename Class",
    "Extract Class",
    "Extract Subclass",
    "Extract Superclass",
    "Extract Interface",
    "Move Source Folder",
    "Change Type Declaration Kind",
    "Collapse Hierarchy",
    "Merge Class",
    "Split Class",
    "Move Attribute",
    "Move And Rename Attribute",
    "Replace Attribute",
    "Pull Up Attribute",
    "Push Down Attribute",
    "Extract Attribute",
    "Inline Attribute",
    "Rename Attribute",
    "Merge Attribute",
    "Split Attribute",
    "Replace Variable With Attribute",
    "Replace Attribute With Variable",
    "Parameterize Attribute",
    "Encapsulate Attribute",
    "Extract Variable",
    "Inline Variable",
    "Rename Variable",
    "Merge Variable",
    "Split Variable",
    "Rename Parameter",
    "Merge Parameter",
    "Split Parameter",
    "Add Parameter",
    "Remove Parameter",
    "Reorder Parameter",
    "Parameterize Variable",
    "Localize Parameter",
    "Change Variable Type",
    "Change Parameter Type",
    "Change Return Type",
    "Change Attribute Type",
    "Extract Package",
    "Move Package",
    "Rename Package",
    "Split Package",
    "Merge Package",
    "Change Method Access Modifier",
    "Change Attribute Access Modifier",
    "Change Class Access Modifier",
    "Add Method Modifier",
    "Remove Method Modifier",
    "Add Attribute Modifier",
    "Remove Attribute Modifier",
    "Add Variable Modifier",
    "Remove Variable Modifier",
    "Add Parameter Modifier",
    "Remove Parameter Modifier",
    "Add Class Modifier",
    "Remove Class Modifier",
    "Add Method Annotation",
    "Remove Method Annotation",
    "Modify Method Annotation",
    "Add Attribute Annotation",
    "Remove Attribute Annotation",
    "Modify Attribute Annotation",
    "Add Class Annotation",
    "Remove Class Annotation",
    "Modify Class Annotation",
    "Add Parameter Annotation",
    "Remove Parameter Annotation",
    "Modify Parameter Annotation",
    "Add Variable Annotation",
    "Remove Variable Annotation",
    "Modify Variable Annotation",
    "Add Thrown Exception Type",
    "Remove Thrown Exception Type",
    "Change Thrown Exception Type",
    "Replace Loop With Pipeline",
    "Replace Pipeline With Loop",
    "Replace Anonymous With Lambda",
    "Replace Anonymous With Class",
    "Replace Lambda With Anonymous",
    "Merge Conditional",
    "Split Conditional",
    "Invert Condition",
    "Merge Catch",
    "Split Try",
    "Move Code",
    "Assert Throws",
    "Try With Resources",
    "Replace Generic With Diamond",
    "Replace Conditional With Ternary",
    "Extract Fixture"
)

# Initialize hashtable with all known types
$refactoringCounts = @{}
foreach ($type in $knownRefactoringTypes) {
    $refactoringCounts[$type] = @{
        W1 = 0
        W2 = 0
    }
}

$totalRefactorings = 0
$newTypesFound = @()

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
            
            # Check if this is a new type not in our predefined list
            if (-not $refactoringCounts.ContainsKey($refType)) {
                Write-Host "  [NEW TYPE DETECTED] '$refType' - Not in predefined list. Adding dynamically..." -ForegroundColor Yellow
                $refactoringCounts[$refType] = @{
                    W1 = 0
                    W2 = 0
                }
                $newTypesFound += $refType
            }
            
            # Increment count for the appropriate window
            $refactoringCounts[$refType][$window]++
            $totalRefactorings++
        }
    }
}

Write-Host ""
Write-Host "Total refactorings found: $totalRefactorings"
if ($newTypesFound.Count -gt 0) {
    Write-Host "New refactoring types found (not in predefined list): $($newTypesFound.Count)" -ForegroundColor Yellow
    foreach ($newType in $newTypesFound) {
        Write-Host "  - $newType" -ForegroundColor Yellow
    }
}

# Calculate totals and percentages for ALL types (including those with 0 counts)
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

Write-Host ""
Write-Host "Total refactoring types in report: $($results.Count)"
Write-Host "  - Known types with counts > 0: $(($results | Where-Object { $_.Total -gt 0 -and $_.'Refactoring Type' -notin $newTypesFound }).Count)"
Write-Host "  - Known types with counts = 0: $(($results | Where-Object { $_.Total -eq 0 }).Count)"
if ($newTypesFound.Count -gt 0) {
    Write-Host "  - New types discovered: $($newTypesFound.Count)" -ForegroundColor Yellow
}

# Filter results based on parameters
if ($ExcludeZeroCounts) {
    $filteredResults = $results | Where-Object { $_.Total -gt 0 }
    Write-Host "  - After excluding zero counts: $($filteredResults.Count)" -ForegroundColor Cyan
} else {
    $filteredResults = $results
}

# Sort by total (descending) and take top N (or all if TopN is 0)
if ($TopN -gt 0) {
    $topResults = $filteredResults | Sort-Object -Property Total -Descending | Select-Object -First $TopN
    $displayTitle = "Apache Ant - Top $TopN Refactoring Types"
} else {
    $topResults = $filteredResults | Sort-Object -Property Total -Descending
    $displayTitle = "Apache Ant - All Refactoring Types (Total: $($topResults.Count))"
}

# Export to CSV
$topResults | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host ""
Write-Host $displayTitle
Write-Host "==========================================="
$topResults | Format-Table -AutoSize

Write-Host ""
Write-Host "CSV file saved to: $OutputFile"
