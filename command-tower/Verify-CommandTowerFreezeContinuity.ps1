[CmdletBinding()]
param(
    [string]$EndpointBaseUri = 'http://127.0.0.1:58883',
    [string]$Tag = 'FREEZE-COMMAND-TOWER-v6',
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Freeze-Continuity-Verification.md')
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$checks = New-Object System.Collections.Generic.List[string]

function Assert-Check([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
    [void]$checks.Add("PASS: $Message")
}

Push-Location $repoRoot
try {
    $mainCommit = (& git rev-parse 'origin/main').Trim()
    $tagCommit = (& git rev-list -n 1 $Tag).Trim()
    Assert-Check ($mainCommit -eq $tagCommit) "Freeze tag $Tag points to origin/main ($mainCommit)."

    $required = @(
        'command-tower/CommandTower.html',
        'command-tower/Serve-CommandTowerStatus.mjs',
        'command-tower/command-tower-live-status-payload.json',
        'command-tower/Invoke-CommandTowerLiveStatusReadOnly.ps1',
        'command-tower/Verify-CommandTowerLiveStatusEndpoint.ps1'
    )
    foreach ($path in $required) {
        & git cat-file -e "origin/main:$path" 2>$null
        Assert-Check ($LASTEXITCODE -eq 0) "Required mainline artifact is present: $path."
    }

    $health = Invoke-RestMethod -Uri "$EndpointBaseUri/healthz" -Method Get
    Assert-Check ($health.status -eq 'ok') 'Loopback health endpoint returned ok.'
    Assert-Check ($health.mode -eq 'approved-bounded-live-readonly') 'Health endpoint reports approved bounded live read-only mode.'
    Assert-Check ($health.read_only -eq $true) 'Health endpoint reports read_only=true.'
    Assert-Check ($health.write_capability -eq $false) 'Health endpoint reports write_capability=false.'

    $status = Invoke-RestMethod -Uri "$EndpointBaseUri/status" -Method Get
    Assert-Check ($status.source_mode -eq 'approved-bounded-live-readonly') 'Status source mode is approved bounded live read-only.'
    Assert-Check ($status.target.role -eq 'nexus_command_tower_ro') 'Status target role is nexus_command_tower_ro.'
    Assert-Check ($status.view_count -eq 8) 'Status reports eight approved views.'
    Assert-Check ($status.summary_count -eq 8) 'Status reports eight aggregate summaries.'
    Assert-Check ($status.read_only -eq $true) 'Status reports read_only=true.'
    Assert-Check ($status.row_data_exported -eq $false) 'Status reports row_data_exported=false.'
    Assert-Check ($status.writes_attempted -eq $false) 'Status reports writes_attempted=false.'
    Assert-Check ($status.write_capability -eq $false) 'Status reports write_capability=false.'
    Assert-Check ($status.promotion_state -eq 'HOLD') 'Status keeps promotion_state=HOLD.'
    Assert-Check ($status.architecture_state -eq 'FROZEN') 'Status keeps architecture_state=FROZEN.'
    foreach ($gate in @('identity', 'transaction_read_only', 'approved_view_scope', 'aggregate_only')) {
        Assert-Check ($status.gates.$gate -eq 'PASS') "Status gate passes: $gate."
    }

    $captured = (Get-Date).ToString('o')
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add('# Command Tower Freeze Continuity Verification')
    [void]$lines.Add('')
    [void]$lines.Add("Verified: $captured")
    [void]$lines.Add('Freeze tag: `' + $Tag + '`')
    [void]$lines.Add('Main commit: `' + $mainCommit + '`')
    [void]$lines.Add('Endpoint: `' + $EndpointBaseUri + '`')
    [void]$lines.Add('')
    [void]$lines.Add('## Result')
    [void]$lines.Add('')
    [void]$lines.Add('**PASS** - The frozen Command Tower mainline artifacts and loopback status contract remain continuous.')
    [void]$lines.Add('')
    [void]$lines.Add('## Read-only evidence')
    [void]$lines.Add('')
    [void]$lines.Add('- Source mode: `' + $status.source_mode + '`')
    [void]$lines.Add('- Role: `' + $status.target.role + '`')
    [void]$lines.Add("- Approved views: $($status.view_count)")
    [void]$lines.Add("- Aggregate summaries: $($status.summary_count)")
    [void]$lines.Add('- Row data exported: `' + $status.row_data_exported + '`')
    [void]$lines.Add('- Writes attempted: `' + $status.writes_attempted + '`')
    [void]$lines.Add('- Write capability: `' + $status.write_capability + '`')
    [void]$lines.Add('- Promotion: `' + $status.promotion_state + '`')
    [void]$lines.Add('- Architecture: `' + $status.architecture_state + '`')
    [void]$lines.Add('')
    [void]$lines.Add('No PostgreSQL writes, schema changes, migrations, workflow changes, credential changes, downstream writes, trading actions, or promotion actions were performed by this verification.')
    Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding utf8
    Write-Output "PASS: freeze continuity verified; receipt written to $ReceiptPath"
}
finally {
    Pop-Location
}
