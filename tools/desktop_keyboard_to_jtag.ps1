param(
    [string]$SystemConsole = "C:\intelFPGA_lite\20.1\quartus\sopc_builder\bin\system-console.exe"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$tclScript = Join-Path $scriptDir "inject_key_jtag.tcl"

if (-not (Test-Path $SystemConsole)) {
    Write-Error "System Console not found: $SystemConsole"
    exit 1
}

if (-not (Test-Path $tclScript)) {
    Write-Error "Injection script not found: $tclScript"
    exit 1
}

$scanMap = @{
    'w' = 0x1D
    'a' = 0x1C
    's' = 0x1B
    'd' = 0x23
    'q' = 0x15
    'e' = 0x24
    'c' = 0x21
    'x' = 0x22
}

Write-Host "Desktop keyboard -> JTAG keyboard injector"
Write-Host "Keys mapped: W A S D Q E C X"
Write-Host "Press Esc to quit."

while ($true) {
    $keyInfo = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    if ($keyInfo.VirtualKeyCode -eq 27) {
        break
    }

    $ch = [char]$keyInfo.Character
    if ([string]::IsNullOrWhiteSpace($ch)) {
        continue
    }

    $k = $ch.ToString().ToLowerInvariant()
    if ($scanMap.ContainsKey($k)) {
        $code = $scanMap[$k]
        $arg = ('0x{0:X2}' -f $code)
        & $SystemConsole --script=$tclScript $arg | Out-Null
        Write-Host ("{0} -> {1}" -f $k.ToUpperInvariant(), $arg)
    }
}

Write-Host "Stopped keyboard bridge."
