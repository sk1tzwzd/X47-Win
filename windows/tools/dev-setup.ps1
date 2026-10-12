# Dev rig: everything in tools\packages.json via winget, Python tooling, git defaults.
# Idempotent; safe to re-run after adding packages. WSL is optional: tools\wsl.ps1 -Install
[CmdletBinding()]
param([string]$GitName, [string]$GitEmail, [string]$OpsTranscript)
. (Join-Path $PSScriptRoot 'lib\Ops.ps1')
if (Ops-Elevate -ScriptPath $PSCommandPath -BoundParams $PSBoundParameters) { exit $LASTEXITCODE }
Ops-StartTranscript $OpsTranscript
try {
    # Store "python" stubs shadow a real install on PATH; drop them (same as toggling the App execution aliases off).
    Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WindowsApps" -Filter 'python*.exe' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Force; X47-Log "removed Store alias $($_.Name)" 'OK' }

    $pkgs = (Get-Content (Join-Path $PSScriptRoot 'packages.json') -Raw | ConvertFrom-Json).packages
    $failed = @()
    foreach ($p in $pkgs) {
        $extra = @()
        if ($p.override) { $extra = @('--override', $p.override) }
        if ($p.id -like 'Python.Python.*') { $extra = @('--scope', 'machine', '--override', '/quiet InstallAllUsers=1 PrependPath=1 Include_launcher=1') }
        if (-not (Ops-Winget -Id $p.id -Extra $extra)) { $failed += $p.id }
    }
    Ops-RefreshPath

    # Python tooling
    if (Get-Command uv -ErrorAction SilentlyContinue) {
        uv tool install pipx 2>&1 | Out-Host
        uv tool update-shell 2>&1 | Out-Host
    }
    # Rust default toolchain (rustup package installs rustup only on some versions)
    if (Get-Command rustup -ErrorAction SilentlyContinue) { rustup default stable 2>&1 | Out-Host }

    # Git defaults. -GitName / -GitEmail are optional (tip: use your GitHub noreply address)
    if ($GitName) { git config --global user.name $GitName }
    if ($GitEmail) { git config --global user.email $GitEmail }
    git config --global init.defaultBranch main
    git config --global core.autocrlf true
    git config --global credential.helper manager
    X47-Log 'git global config set' 'OK'

    Write-Host ''
    Write-Host '--- versions ---' -ForegroundColor Cyan
    foreach ($c in 'python --version', 'py -0', 'uv --version', 'node -v', 'npm -v', 'pwsh -v', 'gh --version', 'git --version', 'rustc -V', 'cargo -V', 'go version') {
        $exe = $c.Split(' ')[0]
        if (Get-Command $exe -ErrorAction SilentlyContinue) { $v = @(Invoke-Expression $c 2>&1); "{0,-16} {1}" -f $exe, "$($v[0])" }
        else { "{0,-16} MISSING (open a new terminal if just installed)" -f $exe }
    }
    if ($failed) { X47-Log ("failed: " + ($failed -join ', ')) 'WARN'; exit 1 }
    X47-Log 'dev setup done' 'OK'
} finally {
    Ops-StopTranscript $OpsTranscript
}
