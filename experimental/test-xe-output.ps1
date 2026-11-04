$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot)
try {
    New-Item -ItemType Directory -Path build -Force | Out-Null
    $demo = Get-Content demo.tex -Raw
    $demo = $demo.Replace('\usepackage{finaldelim}', '\usepackage{finaldelim}\usepackage{experimental/xe-output}')
    $demo = $demo.Replace('\begin{matchedsplit}[rainbow]', '\begin{xeflatmatchedsplit}')
    $demo = $demo.Replace('\begin{matchedsplit}', '\begin{xeflatmatchedsplit}')
    $demo = $demo.Replace('\end{matchedsplit}', '\end{xeflatmatchedsplit}')
    Set-Content -LiteralPath build/xe-output-demo.tex -Value $demo -Encoding utf8
    foreach ($case in @(@('xe-output-test', 'experimental/xe-output-test.tex'), @('xe-output-demo', 'build/xe-output-demo.tex'))) {
        $job = $case[0]
        foreach ($pass in 1..3) {
            $process = Start-Process -FilePath (Get-Command xelatex).Source -ArgumentList @(
                '-interaction=nonstopmode', '-halt-on-error', '-output-directory=build', "-jobname=$job", $case[1]
            ) -WindowStyle Hidden -PassThru -RedirectStandardOutput "build/$job.stdout.txt" -RedirectStandardError "build/$job.stderr.txt"
            if (-not $process.WaitForExit(30000)) { $process.Kill(); throw "$job timed out" }
            if ($process.ExitCode -ne 0) { throw "$job failed: build/$job.log" }
        }
    }
    Write-Host 'XeTeX fixtures compiled. Run experimental/check-xe-output.py with Python + pdfplumber + pypdf.'
} finally { Pop-Location }
