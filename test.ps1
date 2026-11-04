$ErrorActionPreference = 'Stop'
$previousTexmfVar = $env:TEXMFVAR
$previousTexmfCache = $env:TEXMFCACHE
Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Path build -Force | Out-Null
    $env:TEXMFVAR = Join-Path $PSScriptRoot 'build/texmf-var'
    $env:TEXMFCACHE = $env:TEXMFVAR
    New-Item -ItemType Directory -Path $env:TEXMFVAR -Force | Out-Null
    foreach ($engine in @('pdflatex', 'xelatex', 'lualatex')) {
        foreach ($case in @('demo', 'nested_test', 'regression', 'assertions', 'default_split_test', 'override_test', 'override_tbtags_test', 'override_left_test', 'numbered_test', 'numbered_override_test', 'numbered_left_test', 'audit_features', 'rainbow_test', 'rainbow_local_test', 'rainbow_assertions', 'split_placement_test', 'matchedaligned_test', 'alignat_test', 'alignat_override_test', 'alignat_left_test', 'rainbow_groups_test', 'rainbow_groups_unicode_test', 'luatex_flat_test', 'luatex_flat_unicode_test', 'luatex_example', 'luatex_render_test', 'luatex_pagebreak_test')) {
            if ($engine -eq 'pdflatex' -and $case -eq 'rainbow_groups_unicode_test') { continue }
            if ($engine -eq 'pdflatex' -and $case -eq 'demo' -and (Select-String demo.tex -Pattern 'unicode-math' -Quiet)) { continue }
            if ($case -like 'luatex_*' -and $engine -ne 'lualatex') { continue }
            $job = "$engine-$case"
            $passes = if ($case -like 'numbered*' -or $case -like 'alignat*' -or $case -like 'luatex_*') { 2 } else { 1 }
            foreach ($pass in 1..$passes) {
            $process = Start-Process -FilePath (Get-Command $engine).Source -ArgumentList @('-interaction=nonstopmode', '-halt-on-error', '-output-directory=build', "-jobname=$job", "$case.tex") -WindowStyle Hidden -PassThru -RedirectStandardOutput "build/$job.stdout.txt" -RedirectStandardError "build/$job.stderr.txt"
            if (-not $process.WaitForExit(30000)) {
                $process.Kill()
                throw "$job exceeded 30 seconds"
            }
            if ($process.ExitCode -ne 0) { throw "$job failed; see build/$job.log" }
            }
            if ($case -eq 'assertions' -and -not (Select-String -Path "build/$job.log" -Pattern 'ASSERTIONS PASSED' -Quiet)) { throw "$job missing assertions" }
            if ($case -like 'override*') {
                $aux = Get-Content "build/$job.aux" -Raw
                foreach ($label in @(@('one', '1'), @('two', '2'), @('four', '4'))) {
                    if (-not $aux.Contains('\newlabel{eq:' + $label[0] + '}{{' + $label[1] + '}')) { throw "$job incorrect equation label" }
                }
            }
            if ($case -like 'numbered*') {
                $aux = Get-Content "build/$job.aux" -Raw
                foreach ($label in @(@('first','1'), @('second','2'), @('third','3'), @('fourth','4'), @('fifth','5'), @('custom','{A}'), @('bare','B'), @('sixth','6'), @('seventh','7'))) {
                    if (-not $aux.Contains('\newlabel{row:' + $label[0] + '}{{' + $label[1] + '}')) { throw "$job incorrect row label: $($label[0])" }
                }
                if (Select-String -Path "build/$job.log" -Pattern 'undefined references|multiply defined|Overfull' -Quiet) { throw "$job reference or layout warning" }
            }
            if ($case -eq 'audit_features') {
                $aux = Get-Content "build/$job.aux" -Raw
                foreach ($label in @(@('first','1'), @('last','3'), @('split','8'))) {
                    if (-not $aux.Contains('\newlabel{audit:' + $label[0] + '}{{' + $label[1] + '}')) { throw "$job incorrect audit label" }
                }
            }
            if ($case -eq 'split_placement_test' -and -not (Select-String -Path "build/$job.log" -Pattern 'SPLIT PLACEMENT PASSED' -Quiet)) { throw "$job missing placement assertions" }
            if ($case -eq 'matchedaligned_test') {
                if (-not (Select-String -Path "build/$job.log" -Pattern 'MATCHEDALIGNED PLACEMENT PASSED' -Quiet)) { throw "$job missing position assertions" }
                $aux = Get-Content "build/$job.aux" -Raw
                if (-not $aux.Contains('\newlabel{aligned:one}{{1}') -or -not $aux.Contains('\newlabel{aligned:two}{{2}')) { throw "$job incorrect outer numbering" }
            }
            if ($case -like 'alignat*') {
                if (-not (Select-String "build/$job.log" -Pattern 'ALIGNAT ASSERTIONS PASSED' -Quiet)) { throw "$job missing alignat assertions" }
                $aux = Get-Content "build/$job.aux" -Raw
                $labels = @(@('first','1'), @('second','2'), @('custom','{A}'), @('third','3'))
                if ($case -ne 'alignat_test') { $labels += @(@('fourth','4'), @('fifth','5')) }
                foreach ($label in $labels) {
                    if (-not $aux.Contains('\newlabel{at:' + $label[0] + '}{{' + $label[1] + '}')) { throw "$job incorrect alignat label: $($label[0])" }
                }
                if (Select-String "build/$job.log" -Pattern 'undefined references|multiply defined|Overfull' -Quiet) { throw "$job reference or layout warning" }
            }
            if ($case -like 'rainbow_groups*' -and -not (Select-String "build/$job.log" -Pattern 'RAINBOW GROUPS PASSED' -Quiet)) { throw "$job missing group assertions" }
            if ($case -like 'luatex_flat*') {
                if (-not (Select-String "build/$job.log" -Pattern 'LUA FLAT ASSERTIONS PASSED' -Quiet)) { throw "$job missing flat-backend assertions" }
                $aux = Get-Content "build/$job.aux" -Raw
                foreach ($pair in @(@('one','1'), @('custom','{X}'), @('last','3'))) {
                    if (-not $aux.Contains('\newlabel{lf:' + $pair[0] + '}{{' + $pair[1] + '}')) { throw "$job incorrect row label $($pair[0])" }
                }
            }
            Write-Output "PASS $job"
        }
    }
    $badCases = @{
        'right' = '\right)'
        'middle' = '\middle|x'
        'left' = '\left(x'
        'delimiter' = '\left'
        'label-argument' = '\label'
        'tag-argument' = '\tag'
        'tag-star-argument' = '\tag*'
        'intertext-argument' = '\intertext'
        'row-spacing' = 'x &= a\\[3pt'
    }
    foreach ($case in $badCases.Keys) {
        $job = "invalid-$case"
        $body = '\documentclass{article}\usepackage{finaldelim}\begin{document}\[\begin{matchedsplit}' + $badCases[$case] + '\end{matchedsplit}\]\end{document}'
        Set-Content "build/$job.tex" -Value $body -Encoding ascii
        $process = Start-Process -FilePath (Get-Command pdflatex).Source -ArgumentList @('-interaction=nonstopmode', '-halt-on-error', '-output-directory=build', "-jobname=$job", "build/$job.tex") -WindowStyle Hidden -PassThru -RedirectStandardOutput "build/$job.stdout.txt" -RedirectStandardError "build/$job.stderr.txt"
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw "$job timed out" }
        if ($process.ExitCode -eq 0 -or -not (Select-String -Path "build/$job.log" -Pattern 'Package matchedsplit Error' -Quiet)) { throw "$job did not report the expected error" }
        Write-Output "PASS $job (expected error)"
    }
$optionFailures = @{
 'aligned-position' = '\documentclass{article}\usepackage{finaldelim}\begin{document}\[\begin{matchedaligned}[invalid]a&=b\end{matchedaligned}\]\end{document}'
 'empty-package-colors' = '\documentclass{article}\usepackage[colors={}]{finaldelim}\begin{document}x\end{document}'
 'empty-local-colors' = '\documentclass{article}\usepackage{finaldelim}\begin{document}\begin{matchedalign}[rainbow,colors={}]x&=y\end{matchedalign}\end{document}'
 'invalid-rainbow-value' = '\documentclass{article}\usepackage{finaldelim}\begin{document}\begin{matchedalign}[rainbow=invalid]x&=y\end{matchedalign}\end{document}'
}
foreach ($case in $optionFailures.Keys) {
 $job = "invalid-$case"
 Set-Content "build/$job.tex" $optionFailures[$case] -Encoding ascii
 $process = Start-Process -FilePath (Get-Command pdflatex).Source -ArgumentList @('-interaction=nonstopmode','-halt-on-error','-output-directory=build',"-jobname=$job","build/$job.tex") -WindowStyle Hidden -PassThru -RedirectStandardOutput "build/$job.stdout.txt" -RedirectStandardError "build/$job.stderr.txt"
 if (-not $process.WaitForExit(30000)) { $process.Kill(); throw "$job timed out" }
 if ($process.ExitCode -eq 0 -or -not (Select-String "build/$job.log" -Pattern 'Package (matchedsplit|keys) Error|LaTeX Error: Key.*matchedsplit/environment/rainbow' -Quiet)) { throw "$job did not reject invalid options" }
 Write-Output "PASS $job (expected error)"
}


} finally {
    $env:TEXMFVAR = $previousTexmfVar
    $env:TEXMFCACHE = $previousTexmfCache
    Pop-Location
}
