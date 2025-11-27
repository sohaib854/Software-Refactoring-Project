<#
    Script: run_refminer_jmeter.ps1
    Purpose: Runs RefactoringMiner on Apache JMeter repo for commits between
             13 June 2023 and 10 July 2023 (approx. version 5.6.2 window)
             and outputs JSON results.

    Requirements:
        - Java 17+ on PATH
        - Git for Windows on PATH
        - RefactoringMiner unzipped (path specified below)
#>

# ---------------- CONFIGURATION ----------------
$RefMinerPath = "D:\RFM\RefactoringMiner\dist\RefactoringMiner-3.0.11\bin\RefactoringMiner.bat"  # <-- change if different
$BaseDir      = "$env:USERPROFILE\repos"
$JMeterDir    = Join-Path $BaseDir "jmeter"
$OutFile      = "$env:USERPROFILE\Desktop\refactorings_jmeter_5.6.2_20230613_20230710.json"
# ------------------------------------------------

Write-Host "=== RefactoringMiner Runner for Apache JMeter ===`n" -ForegroundColor Cyan

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

# 3. Clone JMeter if needed
if (-not (Test-Path $JMeterDir)) {
    Write-Host "Cloning Apache JMeter repository..."
    git clone https://github.com/apache/jmeter.git $JMeterDir
} else {
    Write-Host "JMeter repo exists. Fetching latest info..."
    Push-Location $JMeterDir
    git fetch --all --tags
    Pop-Location
}

# 4. Get commit SHAs for the window
Push-Location $JMeterDir
$Start = (git rev-list -1 --before="2023-06-13 00:00" --all)
$End   = (git rev-list -1 --before="2023-07-11 00:00" --all)
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
& $RefMinerPath -bc $JMeterDir $Start $End -json $OutFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Completed successfully!"
    Write-Host "JSON output saved to: $OutFile" -ForegroundColor Green
} else {
    Write-Host "`n❌ RefactoringMiner exited with code $LASTEXITCODE." -ForegroundColor Red
}
