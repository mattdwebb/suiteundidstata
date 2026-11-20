param(
    [string]$StataExe = $env:STATA_EXE,
    [string]$PythonExe = "python"
)
$ErrorActionPreference = "Stop"
if (-not $StataExe -or -not (Test-Path -LiteralPath $StataExe)) { throw "Set STATA_EXE or pass -StataExe with a licensed Stata executable." }
$packageRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $PSScriptRoot "release_checks.json") -Raw | ConvertFrom-Json
$scratch = Join-Path ([IO.Path]::GetTempPath()) ("didsuite-stata-check-"+[guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $scratch | Out-Null
$checks = @($config.tests) + @("EXAMPLE")
$records = @()
foreach ($case in $checks) {
    $caseCwd = Join-Path $packageRoot $config.cwd
    $caseFile = Join-Path $caseCwd $case
    if ($case -eq "EXAMPLE") { $caseCwd=$packageRoot; $caseFile=Join-Path $packageRoot "examples/school_policy.do" }
    $label = ($case -replace '[^A-Za-z0-9]', '_')
    $copy = Join-Path $scratch ($label+".do")
    # Old standalone test scripts terminate Stata after their assertions.
    # Remove only that terminal application exit in this temporary runner copy.
    $body = [regex]::Replace((Get-Content -LiteralPath $caseFile -Raw), '(?im)^\s*exit,\s*clear\s*$', '')
    [IO.File]::WriteAllText($copy,$body,[Text.UTF8Encoding]::new($false))
    $status = (Join-Path $scratch ($label+".status")).Replace([char]92,[char]47)
    $log = (Join-Path $scratch ($label+".log")).Replace([char]92,[char]47)
    $copyStata = $copy.Replace([char]92,[char]47)
    $cwdStata = $caseCwd.Replace([char]92,[char]47)
    $wrapper = @'
version 16
clear all
set more off
capture set processors 1
cd "__CWD__"
log using "__LOG__", text replace name(release_runner)
capture noisily do "__COPY__"
local result=_rc
capture log close _all
tempname resultfile
file open `resultfile' using "__STATUS__", write replace
file write `resultfile' "`result'" _n
file close `resultfile'
exit, clear
'@
    $wrapper=$wrapper.Replace('__CWD__',$cwdStata).Replace('__LOG__',$log).Replace('__COPY__',$copyStata).Replace('__STATUS__',$status)
    $launch = Join-Path $scratch "launch.do"
    [IO.File]::WriteAllText($launch,$wrapper,[Text.UTF8Encoding]::new($false))
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $job=Start-Process -FilePath $StataExe -ArgumentList @('/e','do','launch.do') -WorkingDirectory $scratch -WindowStyle Hidden -PassThru
    $job.WaitForExit()
    $watch.Stop()
    $code=if (Test-Path -LiteralPath $status) { (Get-Content -LiteralPath $status -Raw).Trim() } else { 'NO_COMPLETION_RECORD' }
    $records += [pscustomobject]@{test=$case;stata_rc=$code;seconds=$watch.Elapsed.TotalSeconds;log=$log}
    Write-Output "$case : Stata return code $code"
}
$records | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $scratch 'results.json')
Write-Output "Retained test evidence: $scratch"
if ($records | Where-Object { $_.stata_rc -ne '0' }) { throw 'One or more Stata tests failed. Inspect the retained logs.' }
if ($config.compare) {
    & $PythonExe (Join-Path $packageRoot $config.compare)
    if ($LASTEXITCODE -ne 0) { throw 'Frozen numerical comparison failed.' }
}
