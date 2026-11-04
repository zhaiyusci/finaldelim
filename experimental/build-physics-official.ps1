$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    New-Item -ItemType Directory -Force -Path build | Out-Null
    $env:TEXMFVAR = Join-Path $projectRoot 'build/texmf-var'
    $env:TEXMFCACHE = $env:TEXMFVAR
    $texmfDist = (& kpsewhich -var-value=TEXMFDIST).Trim()
    $officialSource = Join-Path $texmfDist 'doc/latex/physics/physics.tex'
    if (!(Test-Path -LiteralPath $officialSource)) {
        throw 'Install the TeX Live physics documentation (physics.tex) before building the pristine reference.'
    }
    Copy-Item -LiteralPath $officialSource -Destination build/physics-official-original.tex -Force
    foreach ($pass in 1..2) {
        & lualatex -interaction=batchmode -halt-on-error -output-directory=build build/physics-official-original.tex
        if ($LASTEXITCODE -ne 0) { throw 'Original manual failed' }
        & lualatex -interaction=batchmode -halt-on-error -output-directory=build -jobname=physics-official-classic '\def\PhysicsClassic{1}\input{experimental/physics-official-finaldelim.tex}'
        if ($LASTEXITCODE -ne 0) { throw 'Classic-font finaldelim manual failed' }
        & lualatex -interaction=batchmode -halt-on-error -output-directory=build experimental/physics-official-finaldelim.tex
        if ($LASTEXITCODE -ne 0) { throw 'Continuous-outline finaldelim manual failed' }
    }
    & lualatex -interaction=batchmode -halt-on-error -output-directory=build displaymath-test.tex
    if ($LASTEXITCODE -ne 0) { throw 'Streaming displaymath regression failed' }
    Write-Output 'Built three eight-page manual variants and the displaymath regression under build/.'
} finally {
    Pop-Location
}
