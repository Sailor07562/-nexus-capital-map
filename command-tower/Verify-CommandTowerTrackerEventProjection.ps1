[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Tracker-Event-Projection-Verification.md')
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $Root 'command-tower-tracker-event-projection.json'
if (-not (Test-Path -LiteralPath $path)) { throw "Missing Tracker projection artifact: $path" }
$projection = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check { param([bool]$Condition, [string]$Message) if (-not $Condition) { [void]$failures.Add($Message) } }

Assert-Check ($projection.projection_status -eq 'READY_FOR_REVIEW') 'Projection status is not READY_FOR_REVIEW.'
Assert-Check ($projection.source_event.run_status -eq 'VERIFIED') 'Source event is not VERIFIED.'
Assert-Check ($projection.source_event.record_readback_replay -eq 'VERIFIED') 'Record/readback/replay is not VERIFIED.'
Assert-Check ($projection.source_event.idempotency -eq 'VERIFIED') 'Idempotency is not VERIFIED.'
Assert-Check ($projection.target.surface -eq 'Tracker Sandbox') 'Projection target is not Tracker Sandbox.'
Assert-Check ($projection.target.review_tab -eq 'Test Log') 'Projection review tab is not Test Log.'
Assert-Check ($projection.target.tab_readback -eq 'BOUNDED_READ_VERIFIED') 'Tracker tab readback is not bounded-read verified.'
Assert-Check ($projection.mapping.field_dictionary -eq 'TBD-LIVE-VERIFICATION') 'Projection invents a field dictionary.'
Assert-Check ($projection.mapping.row_key -eq 'TBD-LIVE-VERIFICATION') 'Projection invents a row key.'
Assert-Check ($projection.mapping.write_mode -eq 'NOT_EXECUTED') 'Projection write mode is not NOT_EXECUTED.'
Assert-Check ([bool]$projection.mapping.reconciliation_required) 'Reconciliation is not required.'
Assert-Check ([bool]$projection.safety.postgresql_authority) 'PostgreSQL authority is not preserved.'
Assert-Check (-not [bool]$projection.safety.write_capability) 'Projection exposes write capability.'
Assert-Check ($projection.safety.records_written -eq 0) 'Projection records_written is not zero.'
Assert-Check (-not [bool]$projection.safety.promotion_authority) 'Projection exposes promotion authority.'
Assert-Check (-not [bool]$projection.safety.trading_authority) 'Projection exposes trading authority.'

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = @(
    '# Command Tower Tracker Event Projection Verification',
    '',
    "Status: **$status**",
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: local proposal validation only. No Tracker read/write request, connector mutation, PostgreSQL change, workflow execution, promotion, or trading action was performed.',
    '',
    '- Workflow 007 source receipt is verified.',
    '- Tracker Sandbox identity and `Test Log` bounded readback are preserved.',
    '- Field dictionary and row key remain TBD-LIVE-VERIFICATION; no fields were guessed.',
    '- Write capability is false and records written is zero.',
    '- Reconciliation remains required before any future write.'
)
if ($failures.Count -gt 0) { $lines += '', '## Failures'; $lines += ($failures | ForEach-Object { "- $_" }) }
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
if ($failures.Count -gt 0) { throw (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine) }
Write-Output "PASS: Tracker event projection verified; receipt written to $ReceiptPath"
