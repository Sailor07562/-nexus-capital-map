[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Status-Payload-Verification.md')
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $Root 'command-tower-status-payload.json'
if (-not (Test-Path -LiteralPath $path)) { throw "Missing status payload: $path" }
$payload = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check { param([bool]$Condition, [string]$Message) if (-not $Condition) { [void]$failures.Add($Message) } }

Assert-Check ($payload.schema_version -eq 1) 'schema_version must be 1.'
Assert-Check ($payload.source_mode -eq 'bounded-read-only-fixture') 'source_mode is outside the bounded fixture boundary.'
Assert-Check ($payload.target.host -eq '127.0.0.1' -and $payload.target.port -eq 5432 -and $payload.target.database -eq 'postgres' -and $payload.target.schema -eq 'nexus' -and $payload.target.role -eq 'nexus_command_tower_ro') 'Target identity does not match the approved bounded target.'
Assert-Check ([bool]$payload.read_only) 'read_only must be true.'
Assert-Check ($payload.view_count -eq 8 -and $payload.summary_count -eq 8) 'Status payload must represent eight views and eight summaries.'
Assert-Check (-not [bool]$payload.row_data_exported) 'row_data_exported must be false.'
Assert-Check (-not [bool]$payload.writes_attempted) 'writes_attempted must be false.'
Assert-Check (-not [bool]$payload.write_capability) 'write_capability must be false.'
Assert-Check ($payload.promotion_state -eq 'HOLD') 'promotion_state must remain HOLD.'
Assert-Check ($payload.architecture_state -eq 'FROZEN') 'architecture_state must remain FROZEN.'
foreach ($property in @('target_identity','read_only_role','migration_lineage','existing_object_inventory','dependency_boundary','last_known_good','sandbox_test')) { Assert-Check (-not [string]::IsNullOrWhiteSpace($payload.gates.$property)) "Missing gate state: $property" }

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = @(
    '# Command Tower Status Payload Verification',
    '',
    "Status: **$status**",
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: local scalar payload validation only. No PostgreSQL connection, schema/data change, migration, connector write, workflow execution, promotion, or trading action was performed.',
    '',
    '- Target identity matches the approved local PostgreSQL target and bounded role.',
    '- Eight approved views and eight aggregate summaries are represented.',
    '- Row export, write attempts, and write capability are all false.',
    '- Promotion remains HOLD and architecture remains FROZEN.'
)
if ($failures.Count -gt 0) { $lines += '', '## Failures'; $lines += ($failures | ForEach-Object { "- $_" }) }
$lines += '', 'This receipt verifies the payload shape only; it does not establish a live API or authorize execution.'
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
if ($failures.Count -gt 0) { throw (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine) }
Write-Output "PASS: status payload verified; receipt written to $ReceiptPath"
