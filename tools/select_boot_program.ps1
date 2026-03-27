param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Program
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$programsDir = Join-Path $repoRoot 'programs'
$dataDir = Join-Path $repoRoot 'data'
$qsfPath = Join-Path $repoRoot 'constraints\de10_lite.qsf'

if ([System.IO.Path]::GetExtension($Program) -eq '.x') {
    $programName = [System.IO.Path]::GetFileNameWithoutExtension($Program)
    $programFile = Join-Path $programsDir $Program
} else {
    $programName = $Program
    $programFile = Join-Path $programsDir ($programName + '.x')
}

if (-not (Test-Path $programFile)) {
    throw "Program hex not found: $programFile"
}

$hexLines = Get-Content $programFile | Where-Object { $_ -match '^[0-9A-Fa-f]+$' }
$depth = 16384

for ($bank = 0; $bank -lt 4; $bank++) {
    $offset = $bank * 2
    $content = New-Object System.Collections.Generic.List[string]

    for ($index = 0; $index -lt $depth; $index++) {
        if ($index -lt $hexLines.Count) {
            $word = $hexLines[$index].PadLeft(8, '0')
            $content.Add($word.Substring(6 - $offset, 2))
        } else {
            $content.Add('00')
        }
    }

    $bankPath = Join-Path $dataDir ("rom_bank{0}.hex" -f $bank)
    [System.IO.File]::WriteAllText($bankPath, ($content -join "`n"))
}

$qsfText = Get-Content $qsfPath -Raw
$memPathPattern = 'set_global_assignment -name VERILOG_MACRO "MEM_PATH=\\"\.\./programs/[^\\"]+\\""'
$memPathRegex = [System.Text.RegularExpressions.Regex]::new($memPathPattern)

if (-not $memPathRegex.IsMatch($qsfText)) {
    throw "Could not find MEM_PATH assignment in $qsfPath"
}

$updatedQsfText = $memPathRegex.Replace(
    $qsfText,
    ('set_global_assignment -name VERILOG_MACRO "MEM_PATH=\"../programs/{0}.x\""' -f $programName),
    1
)

[System.IO.File]::WriteAllText($qsfPath, $updatedQsfText)

Write-Host "Selected boot program: $programName"
Write-Host "Updated: constraints/de10_lite.qsf"
Write-Host "Updated: data/rom_bank0.hex .. data/rom_bank3.hex  ($($hexLines.Count) words, depth=$depth)"
Write-Host ""
Write-Host "IMPORTANT: ROM content is read during synthesis (quartus_map)."
Write-Host "           You must do a FULL recompile (quartus_sh --flow compile)."
Write-Host "           quartus_cdb --update_mif does NOT re-read `$readmemh files."
Write-Host ""
Write-Host "Next:  cd constraints; quartus_sh --flow compile de10_lite"
Write-Host "       quartus_pgm -m jtag -o 'P;de10_lite.sof'"