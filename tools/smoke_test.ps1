param(
    [string]$Program = 'test_framebuffer',
    [switch]$SkipQuartus,
    [switch]$SkipJtag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

. (Join-Path $scriptDir 'setup_windows_env.ps1') | Out-Null

$bashCommand = Get-Command bash -ErrorAction Stop
$quartusCommand = Get-Command quartus_sh -ErrorAction SilentlyContinue
$systemConsoleCommand = Get-Command system-console -ErrorAction SilentlyContinue

function Convert-ToMsysPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WindowsPath
    )

    $normalized = $WindowsPath -replace '\\', '/'
    if ($normalized -match '^([A-Za-z]):/(.*)$') {
        return '/' + $matches[1].ToLower() + '/' + $matches[2]
    }

    throw "Cannot convert path to MSYS form: $WindowsPath"
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    Write-Host ''
    Write-Host "=== $Label ==="
    & $Action
}

$repoRootMsys = Convert-ToMsysPath -WindowsPath $repoRoot

Invoke-Checked -Label "Build $Program" -Action {
    & $bashCommand.Source -lc "export PATH=/mingw64/bin:/ucrt64/bin:/usr/bin:`$PATH; cd '$repoRootMsys'; ./programs/src/build.sh $Program"
}

if (-not $SkipQuartus) {
    if (-not $quartusCommand) {
        throw 'quartus_sh not found on PATH'
    }

    Invoke-Checked -Label 'Quartus compile' -Action {
        Push-Location (Join-Path $repoRoot 'constraints')
        try {
            & $quartusCommand.Source --flow compile de10_lite
        } finally {
            Pop-Location
        }
    }
}

if (-not $SkipJtag) {
    if (-not $systemConsoleCommand) {
        throw 'system-console not found on PATH'
    }

    Invoke-Checked -Label 'JTAG master smoke test' -Action {
        Push-Location $repoRoot
        try {
            & $systemConsoleCommand.Source --script=tools/test_intel_master.tcl
        } finally {
            Pop-Location
        }
    }
}

Write-Host ''
Write-Host 'Smoke test completed successfully.'