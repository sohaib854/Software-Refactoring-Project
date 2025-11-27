<#
    Script: run_refminer_jant_1_10_13_before.ps1
    Purpose: Runs RefactoringMiner on JAnt repo for commits
             before version 1.10.13 — window between 13 Dec 2022 and 9 Jan 2023 (28 days).
             Outputs JSON results to Desktop.

    Requirements:
        - Java 17+ on PATH
        - Git for Windows on PATH
        - RefactoringMiner unzipped (path specified below)
#>

# ---------------- CONFIGURATION ----------------
$RefMinerPath = "D:\RFM\RefactoringMiner\dist\RefactoringMiner-3.0.11\bin\RefactoringMiner.bat"  # <-- adjust if different
$BaseDir      = "$env:USERPROFILE\repos"
$RepoDir      = Join-Path $BaseDir "jant"
$OutFile      = "$env:USERPROFILE\Desktop\refactorings_jant_1.10.13_before_20221213_20230109.json"
# ------------------------------------------------

Write-Host "=== RefactoringMiner Runner for JAnt v1.10.13 BEFORE Window ===`n" -ForegroundColor Cyan

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

# 3. Clone JAnt if needed
if (-not (Test-Path $RepoDir)) {
    Write-Host "Cloning JAnt repository..."
    git clone https://github.com/apache/ant.git $RepoDir
} else {
    Write-Host "JAnt repo exists. Fetching latest info..."
    Push-Location $RepoDir
    git fetch --all --tags
    Pop-Location
}

# 4. Get commit SHAs for the BEFORE window
Push-Location $RepoDir
$Start = (git rev-list -1 --after="2022-12-13 00:00" --all)
$End   = (git rev-list -1 --before="2023-01-10 00:00" --all)
Pop-Location

if (-not $Start -or -not $End) {
    Write-Host "Could not determine start/end commits. Check repo or adjust dates." -ForegroundColor Red
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
