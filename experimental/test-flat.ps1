$ErrorActionPreference = 'Stop'
$oldVar = $env:TEXMFVAR
$oldCache = $env:TEXMFCACHE
Push-Location (Split-Path $PSScriptRoot)
try {
    New-Item -ItemType Directory -Path build -Force | Out-Null
    $env:TEXMFVAR = Join-Path $PWD 'build/texmf-var'
    $env:TEXMFCACHE = $env:TEXMFVAR
    # Build from the user's actual comparison. Never write to demo.tex.
    $demo = Get-Content demo.tex -Raw
    $demo = $demo.Replace('\usepackage{finaldelim}', '\usepackage{finaldelim}\usepackage{experimental/flat-core}')
    $demo = $demo.Replace('\begin{matchedsplit}[rainbow]', '\begin{flatmatchedsplit}')
    $demo = $demo.Replace('\begin{matchedsplit}', '\begin{flatmatchedsplit}')
    $demo = $demo.Replace('\end{matchedsplit}', '\end{flatmatchedsplit}')
    Set-Content -LiteralPath build/flat-demo.tex -Value $demo -Encoding utf8
    foreach ($case in @(
        @('flat-core-test', 'experimental/flat-test.tex'),
        @('flat-core-unicode', 'experimental/flat-test-unicode.tex'),
        @('flat-demo', 'build/flat-demo.tex')
    )) {
        $job = $case[0]
        $process = Start-Process -FilePath (Get-Command lualatex).Source -ArgumentList @(
            '-interaction=nonstopmode', '-halt-on-error', '-output-directory=build',
            "-jobname=$job", $case[1]
        ) -WindowStyle Hidden -PassThru -RedirectStandardOutput "build/$job.stdout.txt" -RedirectStandardError "build/$job.stderr.txt"
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw "$job timed out" }
        if ($process.ExitCode -ne 0) { throw "$job failed: build/$job.log" }
        $log = Get-Content "build/$job.log" -Raw
        $expected = if ($job -eq 'flat-demo') { 2 } else { 11 }
        if ([regex]::Matches($log, 'FLAT CORE PASS:').Count -ne $expected) { throw "$job missing geometry checks" }
        if ($job -ne 'flat-demo' -and -not $log.Contains('FLAT SINGLE EVALUATION PASS')) { throw "$job duplicated source evaluation" }
    }
    Write-Host 'PASS: 24 physical-partition checks, two single-evaluation checks, current demo compiled.'
    Write-Host 'Run experimental/check-flat-pdf.py with Python + pdfplumber for independent PDF checks.'
} finally {
    $env:TEXMFVAR = $oldVar
    $env:TEXMFCACHE = $oldCache
    Pop-Location
}
