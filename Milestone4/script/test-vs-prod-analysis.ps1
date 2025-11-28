Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Info {
    param([string]$Message)
    Write-Host $Message
}

function Normalize-PathToLower {
    param([string]$p)
    if ($null -eq $p) { return "" }
    return ($p -replace '\\','/').ToLower()
}

function To-AbsolutePath {
    param(
        [string]$RepoRoot,
        [string]$GitPath
    )
    if ([string]::IsNullOrWhiteSpace($GitPath)) { return "" }
    $rel = $GitPath -replace '/','\'
    return (Join-Path -Path $RepoRoot -ChildPath $rel)
}

function Classify-File {
    param(
        [string]$ProjectName,
        [string]$RepoRoot,
        [string]$GitFilePath
    )

    $lower = Normalize-PathToLower $GitFilePath

    switch ($ProjectName) {

        "JAnt" {
            if ($lower -match '/test/' -or $lower -match '^src/tests') { return "Test" }
            if ($lower -match '^src/' -and -not ($lower -match 'src/tests')) { return "Production" }
            return "Other"
        }

        "JMeter" {
            if ($lower -match '/src/test/java/') { return "Test" }
            if ($lower -match '/src/main/java/') { return "Production" }
            return "Other"
        }

        "JFreeChart" {
    	if ($lower -match '^src/test/java/') { return "Test" }
    	elseif ($lower -match '^src/main/java/') { return "Production" }
    	else { return "Other" }
	}

        default {
            if ($lower -match '/test/') { return "Test" }
            if ($lower -match 'src/') { return "Production" }
            return "Other"
        }
    }
}

function Get-Files-For-Window {
    param(
        [string]$RepoRoot,
        [string]$StartDate,
        [string]$EndDate
    )

    $gitCmd = "git -C `"$RepoRoot`" log --since=`"$StartDate`" --until=`"$EndDate`" --pretty=format:`"%H`" --no-merges"
    $commitList = Invoke-Expression $gitCmd 2>$null

    if ([string]::IsNullOrWhiteSpace($commitList)) { return @{} }

    $unique = @{}  

    foreach ($sha in $commitList -split "`n") {
        $shaTrim = $sha.Trim()
        if ($shaTrim -eq "") { continue }

        $dateCmd = "git -C `"$RepoRoot`" show -s --format=`"%ci`" $shaTrim"
        $commitDate = Invoke-Expression $dateCmd 2>$null
        $commitDate = $commitDate.Trim()

        $diffCmd = "git -C `"$RepoRoot`" diff-tree --no-commit-id --name-only -r $shaTrim"
        $filesRaw = Invoke-Expression $diffCmd 2>$null
        if ($filesRaw -eq $null) { continue }

        foreach ($f in $filesRaw -split "`n") {
            $fTrim = $f.Trim()
            if ($fTrim -eq "") { continue }
            if ($fTrim -match '\.java$') {
                $norm = $fTrim -replace '\\','/'
                if (-not $unique.ContainsKey($norm)) {
                    $unique[$norm] = $commitDate
                }
            }
        }
    }

    return $unique
}

function Analyze-Project-Windows {
    param(
        [string]$ProjectName,
        [string]$RepoRoot,
        [array]$WindowsArray,
        [string]$OutCsv
    )

    Write-Info ("=== Processing " + $ProjectName + " -> " + $OutCsv + " ===")

    if (Test-Path $OutCsv) { Remove-Item $OutCsv -Force }

    "Window,Path,Type,CommitDate" | Out-File -FilePath $OutCsv -Encoding UTF8

    for ($i = 0; $i -lt $WindowsArray.Length; $i += 4) {
        $version = $WindowsArray[$i]
        $winLabel = $WindowsArray[$i + 1]
        $start = $WindowsArray[$i + 2]
        $end = $WindowsArray[$i + 3]

        Write-Info ("Window: " + $winLabel + " (" + $start + " -> " + $end + ")")

        $files = Get-Files-For-Window -RepoRoot $RepoRoot -StartDate $start -EndDate $end

        if (-not $files.Keys) {
            Write-Info "  No Java files changed in this window."
            continue
        }

        foreach ($gitPath in $files.Keys) {
            $type = Classify-File -ProjectName $ProjectName -RepoRoot $RepoRoot -GitFilePath $gitPath
            if ($type -eq "Other") { continue }
            $abs = To-AbsolutePath -RepoRoot $RepoRoot -GitPath $gitPath
            $safePath = $abs -replace ',',';'
            $commitDate = $files[$gitPath]
            "$winLabel,$safePath,$type,$commitDate" | Out-File -FilePath $OutCsv -Append -Encoding UTF8
        }
    }

    Write-Info ("Wrote CSV: " + $OutCsv)
    Write-Info ""
}

# -------------------------
# --- CONFIG: repo paths and windows
# -------------------------
$JAntRepo = "C:\Users\Muhammad Sohaib Arif\repos\jant"
$JMeterRepo = "C:\Users\Muhammad Sohaib Arif\repos\jmeter"
$JFreeChartRepo = "C:\Users\Muhammad Sohaib Arif\repos\jfreechart"

$JAntWindows = @(
    "1.10.15","W1","2024-08-01","2024-08-28",
    "1.10.15","W2","2024-08-30","2024-09-26",
    "1.10.14","W1","2023-07-24","2023-08-20",
    "1.10.14","W2","2023-08-22","2023-09-18",
    "1.10.13","W1","2022-12-13","2023-01-09",
    "1.10.13","W2","2023-01-11","2023-02-07"
)

$JMeterWindows = @(
    "5.6.3","W1","2023-12-24","2024-01-06",
    "5.6.3","W2","2024-01-08","2024-01-21",
    "5.6.2","W1","2023-06-13","2023-07-10",
    "5.6.2","W2","2023-07-12","2023-08-08",
    "5.6.1","W1","2023-04-22","2023-05-19",
    "5.6.1","W2","2023-05-21","2023-06-17"
)

$JFreeChartWindows = @(
    "1.5.6","W1","2025-04-23","2025-05-20",
    "1.5.6","W2","2025-05-22","2025-06-18",
    "1.5.5","W1","2024-05-27","2024-06-23",
    "1.5.5","W2","2024-06-25","2024-07-22",
    "1.5.4","W1","2022-12-11","2023-01-07",
    "1.5.4","W2","2023-01-09","2023-02-05"
)

# -------------------------
# --- Run for each project
# -------------------------
if (Test-Path $JAntRepo) {
    Analyze-Project-Windows -ProjectName "JAnt" -RepoRoot $JAntRepo -WindowsArray $JAntWindows -OutCsv "JAnt_Windows.csv"
} else { Write-Info "JAnt repository not found. Skipping." }

if (Test-Path $JMeterRepo) {
    Analyze-Project-Windows -ProjectName "JMeter" -RepoRoot $JMeterRepo -WindowsArray $JMeterWindows -OutCsv "JMeter_Windows.csv"
} else { Write-Info "JMeter repository not found. Skipping." }

if (Test-Path $JFreeChartRepo) {
    Analyze-Project-Windows -ProjectName "JFreeChart" -RepoRoot $JFreeChartRepo -WindowsArray $JFreeChartWindows -OutCsv "JFreeChart_Windows.csv"
} else { Write-Info "JFreeChart repository not found. Skipping." }

Write-Info "All done."
