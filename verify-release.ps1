param([string]$Archive = (Join-Path $PSScriptRoot 'dist/finaldelim.zip'))
$ErrorActionPreference = 'Stop'
$archivePath = (Resolve-Path -LiteralPath $Archive).Path
$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash
$checkRoot = Join-Path ([IO.Path]::GetTempPath()) ('finaldelim-release-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $checkRoot | Out-Null
Write-Output "Clean verification directory: $checkRoot"
Expand-Archive -LiteralPath $archivePath -DestinationPath $checkRoot
$packageRoot = Join-Path $checkRoot 'finaldelim'
$expected = @('finaldelim.sty','finaldelim-luatex.sty','finaldelim.lua','finaldelim.tex','finaldelim.pdf','numbered_example.tex','luatex_example.tex','README.md','LICENSE','CHANGELOG.md','MANIFEST.md')
$actual = @(Get-ChildItem -LiteralPath $packageRoot -File | ForEach-Object Name)
if (Compare-Object ($expected | Sort-Object) ($actual | Sort-Object)) { throw 'Unexpected distribution contents' }
# Add test harness files only. The implementation and manual must come from ZIP.
Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.tex -File | Where-Object { $_.Name -notin $expected } | ForEach-Object {
 Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $packageRoot $_.Name)
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'test.ps1') -Destination $packageRoot
$savedInputs=$env:TEXINPUTS; $savedHome=$env:TEXMFHOME
$savedVar=$env:TEXMFVAR; $savedCache=$env:TEXMFCACHE
Push-Location -LiteralPath $packageRoot
try {
 $env:TEXINPUTS='.;'
 $env:TEXMFHOME=Join-Path $checkRoot 'empty-texmf-home'
 $env:TEXMFVAR=Join-Path $checkRoot 'texmf-var'
 $env:TEXMFCACHE=$env:TEXMFVAR
 New-Item -ItemType Directory -Path $env:TEXMFHOME,$env:TEXMFVAR,build -Force | Out-Null
 $resolved = (& kpsewhich finaldelim.sty).Trim()
 if ((Resolve-Path -LiteralPath $resolved).Path -ne (Join-Path $packageRoot 'finaldelim.sty')) { throw 'Wrong package resolved' }
 & .\test.ps1
 function Invoke-ReleaseCompile([string]$Engine,[string]$Source,[string]$Job,[bool]$ExpectFailure=$false) {
  $p=Start-Process -FilePath (Get-Command $Engine).Source -ArgumentList @('-interaction=nonstopmode','-halt-on-error','-recorder','-output-directory=build',"-jobname=$Job",$Source) -WindowStyle Hidden -PassThru -RedirectStandardOutput "build/$Job.stdout.txt" -RedirectStandardError "build/$Job.stderr.txt"
  if (-not $p.WaitForExit(45000)) { $p.Kill(); throw "$Job timed out" }
  if ($ExpectFailure) {
   if ($p.ExitCode -eq 0 -or -not (Select-String "build/$Job.log" -Pattern 'LaTeX 2020-10-01 or newer is required' -Quiet)) { throw "$Job did not reject an old format" }
  } elseif ($p.ExitCode -ne 0) { throw "$Job failed" }
 }
 foreach($engine in @('pdflatex','xelatex','lualatex')) {
  foreach($fixture in @('finaldelim','numbered_example')) {
   1..2 | ForEach-Object { Invoke-ReleaseCompile $engine "$fixture.tex" "$engine-release-$fixture" }
   if (Select-String "build/$engine-release-$fixture.log" -Pattern 'undefined references|multiply defined|Overfull' -Quiet) { throw 'Manual/example reference or layout warning' }
   Write-Output "PASS $engine clean release $fixture"
  }
  foreach($fixture in @('numbered_override_test','rainbow_assertions','audit_features','default_split_test')) {
   $source="minimum-$fixture.tex"
   Set-Content $source -Value ('\RequirePackage[2020/10/01]{latexrelease}' + "`n" + '\input{' + $fixture + '.tex}') -Encoding ascii
   Invoke-ReleaseCompile $engine $source "$engine-minimum-$fixture"
   if ($fixture -eq 'numbered_override_test') {
    Invoke-ReleaseCompile $engine $source "$engine-minimum-$fixture"
    $aux=Get-Content "build/$engine-minimum-$fixture.aux" -Raw
    foreach($label in @(@('first','1'),@('third','3'),@('fifth','5'),@('seventh','7'))) {
     if (-not $aux.Contains('\newlabel{row:' + $label[0] + '}{{' + $label[1] + '}')) { throw 'Rollback numbering mismatch' }
    }
   }
   if (-not (Select-String "build/$engine-minimum-$fixture.log" -SimpleMatch -Pattern 'LaTeX2e <2020/10/01>' -Quiet)) { throw 'Requested kernel rollback was not applied' }
   Write-Output "PASS $engine minimum-kernel $fixture"
  }
  Set-Content old-format.tex -Value '\RequirePackage[2020/02/02]{latexrelease}\documentclass{article}\usepackage{finaldelim}\begin{document}x\end{document}' -Encoding ascii
  Invoke-ReleaseCompile $engine old-format.tex "$engine-old-format" $true
  Write-Output "PASS $engine rejects old format"
 }
 $inputs=Select-String build/pdflatex-release-finaldelim.fls -Pattern '^INPUT .*finaldelim\.sty$'
 if (-not $inputs) { throw 'No package provenance recorded' }
 foreach($entry in $inputs) {
  $inputPath=$entry.Line.Substring(6)
  if ((Resolve-Path -LiteralPath $inputPath).Path -ne (Join-Path $packageRoot 'finaldelim.sty')) { throw 'A non-archive package was loaded' }
 }
 if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $archiveHash) { throw 'Archive changed during verification' }
 Write-Output "Archive SHA256: $archiveHash"
 Write-Output "Verification outputs: $packageRoot/build"
} finally {
 $env:TEXINPUTS=$savedInputs; $env:TEXMFHOME=$savedHome
 $env:TEXMFVAR=$savedVar; $env:TEXMFCACHE=$savedCache
 Pop-Location
}
