Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir

function Add-PathEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathEntry
    )

    if (-not (Test-Path $PathEntry)) {
        return $false
    }

    $current = @($env:PATH -split ';' | Where-Object { $_ })
    if ($current -contains $PathEntry) {
        return $true
    }

    $env:PATH = $PathEntry + ';' + $env:PATH
    return $true
}

# Search well-known Quartus install locations (home machine + York lab).
# The first directory that exists wins.
$quartusRoots = @(
    'C:\altera_lite\25.1std\quartus',
    'C:\intelFPGA_lite\20.1\quartus',
    'C:\intelFPGA_lite\25.1std\quartus',
    'C:\altera_lite\20.1\quartus'
)

$quartusRoot = $null
foreach ($candidate in $quartusRoots) {
    if (Test-Path "$candidate\bin64\quartus_sh.exe") {
        $quartusRoot = $candidate
        break
    }
}

# Locate MSYS2: honour $env:MSYS2_ROOT, then probe common install paths.
$msys2Root = if ($env:MSYS2_ROOT -and (Test-Path $env:MSYS2_ROOT)) { $env:MSYS2_ROOT }
             else {
                 $candidates = @('C:\msys64','C:\msys2','C:\tools\msys64',
                                 "$env:USERPROFILE\msys64","$env:USERPROFILE\scoop\apps\msys2\current")
                 ($candidates | Where-Object { Test-Path $_ } | Select-Object -First 1)
             }

if (-not $msys2Root) {
    Write-Warning 'MSYS2 not found. Set $env:MSYS2_ROOT or install to C:\msys64.'
}

$pathEntries = @(
    "$msys2Root\usr\bin",
    "$msys2Root\mingw64\bin",
    "$msys2Root\ucrt64\bin"
)

if ($quartusRoot) {
    $pathEntries = @(
        "$quartusRoot\bin64",
        "$quartusRoot\sopc_builder\bin"
    ) + $pathEntries
} else {
    Write-Warning 'No Quartus installation found. Searched:'
    foreach ($candidate in $quartusRoots) {
        Write-Warning "  $candidate"
    }
}

$added = New-Object System.Collections.Generic.List[string]
$missing = New-Object System.Collections.Generic.List[string]

foreach ($entry in $pathEntries) {
    if (Add-PathEntry -PathEntry $entry) {
        $added.Add($entry)
    } else {
        $missing.Add($entry)
    }
}

$env:EECS3216_PROJECT_ROOT = $repoRoot

$bashCommand = Get-Command bash -ErrorAction SilentlyContinue
$gccCommand = Get-Command riscv64-unknown-elf-gcc -ErrorAction SilentlyContinue
$quartusCommand = Get-Command quartus_sh -ErrorAction SilentlyContinue
$systemConsole = Get-Command system-console -ErrorAction SilentlyContinue

Write-Host 'EECS-3216 environment configured for this PowerShell session.'
Write-Host "Repo root: $repoRoot"

if ($added.Count -gt 0) {
    Write-Host 'Verified PATH entries:'
    foreach ($entry in $added) {
        Write-Host "  $entry"
    }
}

if ($missing.Count -gt 0) {
    Write-Warning 'Missing expected tool directories:'
    foreach ($entry in $missing) {
        Write-Warning "  $entry"
    }
}

Write-Host 'Resolved tools:'
Write-Host ("  bash: {0}" -f ($(if ($bashCommand) { $bashCommand.Source } else { 'NOT FOUND' })))
Write-Host ("  quartus_sh: {0}" -f ($(if ($quartusCommand) { $quartusCommand.Source } else { 'NOT FOUND' })))
Write-Host ("  system-console: {0}" -f ($(if ($systemConsole) { $systemConsole.Source } else { 'NOT FOUND' })))
Write-Host ("  riscv64-unknown-elf-gcc: {0}" -f ($(if ($gccCommand) { $gccCommand.Source } else { 'NOT FOUND' })))

Write-Host ''
Write-Host 'Use this in the current shell with:'
Write-Host '  . .\tools\setup_windows_env.ps1'