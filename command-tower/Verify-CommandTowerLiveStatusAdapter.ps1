[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$PayloadPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'command-tower-live-status-payload.json'),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Live-Status-Adapter-Verification.md')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $PayloadPath)) { throw "Missing live status payload: $PayloadPath" }
$payload = Get-Content -LiteralPath $PayloadPath -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check { param([bool]$Condition, [string]$Message) if (-not $Condition) { [void]$failures.Add($Message) } }

Assert-Check ($payload.schema_version -eq 1) 'schema_version must be 1.'
Assert-Check ($payload.source_mode -eq 'approved-bounded-live-readonly') 'source_mode is outside the approved live read-only boundary.'
Assert-Check ($payload.target.host -eq '127.0.0.1' -and $payload.target.port -eq 5432 -and $payload.target.database -eq 'postgres' -and $payload.target.schema -eq 'nexus' -and $payload.target.role -eq 'nexus_command_tower_ro') 'Target identity does not match the approved local role.'
Assert-Check ([bool]$payload.read_only) 'read_only must be true.'
Assert-Check ($payload.view_count -eq 8 -and $payload.summary_count -eq 8) 'Payload must represent eight approved views and eight aggregate summaries.'
Assert-Check (-not [bool]$payload.row_data_exported) 'row_data_exported must be false.'
Assert-Check (-not [bool]$payload.writes_attempted) 'writes_attempted must be false.'
Assert-Check (-not [bool]$payload.write_capability) 'write_capability must be false.'
Assert-Check ($payload.promotion_state -eq 'HOLD') 'promotion_state must remain HOLD.'
Assert-Check ($payload.architecture_state -eq 'FROZEN') 'architecture_state must remain FROZEN.'
Assert-Check (@($payload.summaries | Where-Object { $_.aggregate_only -ne $true }).Count -eq 0) 'Every summary must be aggregate-only.'
Assert-Check ($payload.gates.identity -eq 'PASS' -and $payload.gates.transaction_read_only -eq 'PASS' -and $payload.gates.approved_view_scope -eq 'PASS' -and $payload.gates.aggregate_only -eq 'PASS') 'One or more live read-only gates failed.'

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = @(
    '# Command Tower Live Status Adapter Verification',
    '',
    "Status: **$status**",
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: bounded local live refresh through the approved PostgreSQL read-only role. No browser database connection, row export, write path, schema change, migration, workflow change, promotion, trading, or transfer action is included.',
    '',
    '- The payload identifies the approved local target and role.',
    '- The adapter forced a read-only transaction for identity and every aggregate query.',
    '- Exactly eight approved views are represented as aggregate summaries only.',
    '- Row export, writes, and write capability remain false.',
    '- Promotion remains HOLD and architecture remains FROZEN.'
)
if ($failures.Count -gt 0) { $lines += '', '## Failures'; $lines += ($failures | ForEach-Object { "- $_" }) }
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
if ($failures.Count -gt 0) { throw (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine) }
Write-Output "PASS: live status adapter payload verified; receipt written to $ReceiptPath"
