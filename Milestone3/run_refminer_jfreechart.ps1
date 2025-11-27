<#
    Script: run_refminer_jfreechart.ps1
    Purpose: Runs RefactoringMiner on JFreeChart repo for commits between
             25 June 2024 and 22 July 2024 (approx. version 1.5.1 window)
             and outputs JSON results.

    Requirements:
        - Java 17+ on PATH
        - Git for Windows on PATH
        - RefactoringMiner unzipped (path specified below)
#>

# ---------------- CONFIGURATION ----------------
$RefMinerPath = "D:\RFM\RefactoringMiner\dist\RefactoringMiner-3.0.11\bin\RefactoringMiner.bat"  # <-- adjust if different
$BaseDir      = "$env:USERPROFILE\repos"
$RepoDir      = Join-Path $BaseDir "jfreechart"
$OutFile      = "$env:USERPROFILE\Desktop\refactorings_jfreechart_1.5.1_20240625_20240722.json"
# ------------------------------------------------

Write-Host "=== RefactoringMiner Runner for JFreeChart ===`n" -ForegroundColor Cyan

# 1. Check Java and Git
if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    Write-Host "Java not found. Please install Java 17+ and add to PATH." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "Git not found. Please install Git for Windows and add to PATH." -ForegroundColor Red
    exit 1
}

# 2. Ensure base folder exists
if (-not (Test-Path $BaseDir)) {
    New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null
}

# 3. Clone JFreeChart if needed
if (-not (Test-Path $RepoDir)) {
    Write-Host "Cloning JFreeChart repository..."
    git clone https://github.com/jfree/jfreechart.git $RepoDir
} else {
    Write-Host "JFreeChart repo exists. Fetching latest info..."
    Push-Location $RepoDir
    git fetch --all --tags
    Pop-Location
}

# 4. Get commit SHAs for the date window
Push-Location $RepoDir
$Start = (git rev-list -1 --after="2024-06-25 00:00" --all)
$End   = (git rev-list -1 --before="2024-07-23 00:00" --all)
Pop-Location

if (-not $Start -or -not $End) {
    Write-Host "Could not determine start/end commits. Check repo." -ForegroundColor Red
    exit 1
}

Write-Host "Start commit: $Start"
Write-Host "End commit  : $End"
Write-Host ""

# 5. Verify RefactoringMiner path
if (-not (Test-Path $RefMinerPath)) {
    Write-Host "RefactoringMiner not found at: $RefMinerPath" -ForegroundColor Red
    Write-Host "Please update the path variable near top of script." -ForegroundColor Yellow
    exit 1
}

# 6. Run RefactoringMiner
Write-Host "Running RefactoringMiner (this may take a while)...`n"
& $RefMinerPath -bc $RepoDir $Start $End -json $OutFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Completed successfully!"
    Write-Host "JSON output saved to: $OutFile" -ForegroundColor Green
} else {
    Write-Host "`n❌ RefactoringMiner exited with code $LASTEXITCODE." -ForegroundColor Red
}
