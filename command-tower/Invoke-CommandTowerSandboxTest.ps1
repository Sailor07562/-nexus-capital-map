[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Sandbox-Test-Receipt.md')
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Check {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { [void]$failures.Add($Message) }
}

function Read-JsonFile {
    param([string]$Name)
    $path = Join-Path $Root $Name
    Assert-Check (Test-Path -LiteralPath $path) "Missing evidence file: $Name"
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    return (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json)
}

$required = @(
    'CommandTower.html',
    'CommandTower-Integration-Evidence.md',
    'CommandTower-Integration-Mapping-Contract.md',
    'CommandTower-Dependency-Boundary-Review.md',
    'command-tower-readonly-adapter.json',
    'command-tower-summary-readback.json',
    'command-tower-migration-object-evidence.json',
    'command-tower-role-creation-evidence.json'
)
foreach ($name in $required) {
    Assert-Check (Test-Path -LiteralPath (Join-Path $Root $name)) "Missing package artifact: $name"
}

$htmlPath = Join-Path $Root 'CommandTower.html'
if (Test-Path -LiteralPath $htmlPath) {
    $html = Get-Content -LiteralPath $htmlPath -Raw
    Assert-Check ($html -match 'STRUCTURE FROZEN') 'Dashboard does not show the frozen architecture state.'
    Assert-Check ($html -match 'browser path disabled') 'Dashboard does not state that browser binding is disabled.'
    Assert-Check ($html -match 'No database connection') 'Dashboard does not state the static browser boundary.'
    Assert-Check ($html -notmatch '<script\b|fetch\s*\(|XMLHttpRequest|WebSocket|<form\b') 'Dashboard contains an executable or write-capable browser boundary.'
}

$summary = Read-JsonFile 'command-tower-summary-readback.json'
if ($null -ne $summary) {
    $summaries = @($summary.summaries)
    Assert-Check ($summaries.Count -eq 8) "Expected 8 aggregate summaries; found $($summaries.Count)."
    Assert-Check ($summary.identity.role -eq 'nexus_command_tower_ro') 'Aggregate evidence role is not nexus_command_tower_ro.'
    Assert-Check ([bool]$summary.identity.default_transaction_read_only) 'Aggregate evidence is not marked transaction-read-only.'
    Assert-Check (-not [bool]$summary.identity.row_data_included) 'Aggregate evidence includes row data.'
    Assert-Check (-not [bool]$summary.identity.write_path) 'Aggregate evidence exposes a write path.'
    Assert-Check (-not [bool]$summary.row_data_exported) 'Aggregate evidence marks row data as exported.'
    Assert-Check (-not [bool]$summary.writes_attempted) 'Aggregate evidence marks writes as attempted.'
    foreach ($item in $summaries) { Assert-Check ([bool]$item.aggregate_only) "Summary is not aggregate-only: $($item.view)" }
}

$adapter = Read-JsonFile 'command-tower-readonly-adapter.json'
if ($null -ne $adapter) {
    $views = @($adapter.approved_views)
    Assert-Check ($views.Count -eq 8) "Expected 8 approved adapter views; found $($views.Count)."
    Assert-Check ($adapter.identity.role -eq 'nexus_command_tower_ro') 'Adapter evidence role is not nexus_command_tower_ro.'
    Assert-Check ([bool]$adapter.identity.default_transaction_read_only) 'Adapter evidence is not marked transaction-read-only.'
    Assert-Check (-not [bool]$adapter.identity.row_data_included) 'Adapter evidence includes row data.'
    Assert-Check (-not [bool]$adapter.identity.write_path) 'Adapter evidence exposes a write path.'
    Assert-Check ([bool]$adapter.summary_readback.aggregate_only) 'Adapter summary readback is not aggregate-only.'
    Assert-Check (-not [bool]$adapter.summary_readback.row_data_exported) 'Adapter summary readback marks row data as exported.'
    Assert-Check (-not [bool]$adapter.summary_readback.writes_attempted) 'Adapter summary readback marks writes as attempted.'
    foreach ($view in $views) {
        Assert-Check ([bool]$view.exists -and [bool]$view.has_rows) "Approved view is not present with rows: $($view.view)"
    }
}

$migration = Read-JsonFile 'command-tower-migration-object-evidence.json'
if ($null -ne $migration) {
    $objects = @($migration.approved_objects)
    Assert-Check ($migration.status -eq 'PASS') 'Migration/object evidence status is not PASS.'
    Assert-Check ($migration.migration_lineage.maximum_version -eq 262) 'Migration maximum is not 262.'
    Assert-Check ($migration.migration_lineage.checksum_count -eq 262) 'Checksum count is not 262.'
    Assert-Check ($migration.migration_lineage.checksum_gate -eq 'PASS') 'Migration checksum gate is not PASS.'
    Assert-Check ($objects.Count -eq 8) "Expected 8 approved objects; found $($objects.Count)."
    Assert-Check ($migration.object_gate -eq 'PASS') 'Approved object gate is not PASS.'
    foreach ($object in $objects) { Assert-Check ($object.status -eq 'present' -and -not [string]::IsNullOrWhiteSpace($object.definition_md5)) "Approved object hash missing: $($object.view)" }
    Assert-Check (-not [bool]$migration.row_data_exported) 'Migration evidence marks row data as exported.'
    Assert-Check (-not [bool]$migration.writes_attempted) 'Migration evidence marks writes as attempted.'
    Assert-Check (-not [bool]$migration.schema_or_data_changed) 'Migration evidence marks schema/data as changed.'
    Assert-Check (-not [bool]$migration.migrations_changed) 'Migration evidence marks migrations as changed.'
}

$role = Read-JsonFile 'command-tower-role-creation-evidence.json'
if ($null -ne $role) {
    Assert-Check ($role.target.role -eq 'nexus_command_tower_ro') 'Role evidence names an unexpected role.'
    Assert-Check (-not [bool]$role.default_privileges_changed) 'Role evidence marks default privileges as changed.'
    Assert-Check (-not [bool]$role.schema_or_data_changed) 'Role evidence marks schema/data as changed.'
    Assert-Check (-not [bool]$role.migration_or_workflow_changed) 'Role evidence marks migrations/workflows as changed.'
    Assert-Check ([bool]$role.secrets_persisted -eq $false) 'Role evidence marks secrets as persisted.'
}

$captured = (Get-Date).ToString('o')
$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add('# Command Tower Sandbox Test Receipt')
[void]$lines.Add('')
[void]$lines.Add("Status: **$status**")
[void]$lines.Add("Captured: $captured")
[void]$lines.Add('')
[void]$lines.Add('Scope: local package validation only. No PostgreSQL connection, schema/data change, migration, connector write, workflow execution, promotion, or trading action was performed.')
[void]$lines.Add('')
[void]$lines.Add('- Dashboard boundary: static fixture-backed page; executable browser/network/write surfaces absent.')
[void]$lines.Add('- Aggregate readback: eight summaries, aggregate-only, no row export, no writes attempted.')
[void]$lines.Add('- Adapter envelope: eight approved views present with rows under `nexus_command_tower_ro`; read-only flags preserved.')
[void]$lines.Add('- Migration/object evidence: migration 262, checksum gate PASS, eight approved object hashes present.')
[void]$lines.Add('- Role evidence: bounded role named, no default-privilege/schema/data/migration/workflow changes recorded.')
if ($failures.Count -gt 0) {
    [void]$lines.Add('')
    [void]$lines.Add('## Failures')
    foreach ($failure in $failures) { [void]$lines.Add("- $failure") }
}
[void]$lines.Add('')
[void]$lines.Add('Architecture remains **FROZEN**. This receipt is a sandbox verification artifact, not an architecture amendment.')

$parent = Split-Path -Parent $ReceiptPath
if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8

if ($failures.Count -gt 0) {
    Write-Error (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine)
    exit 1
}

Write-Output "PASS: Command Tower sandbox test receipt written to $ReceiptPath"
