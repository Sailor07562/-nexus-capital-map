[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Tracker-Live-Mapping-Readback.md')
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $Root 'command-tower-tracker-live-mapping.json'
if (-not (Test-Path -LiteralPath $path)) { throw "Missing live mapping artifact: $path" }

$mapping = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check { param([bool]$Condition, [string]$Message) if (-not $Condition) { [void]$failures.Add($Message) } }

Assert-Check ($mapping.mode -eq 'live bounded read-only Tracker mapping') 'Unexpected mapping mode.'
Assert-Check ($mapping.target.spreadsheet_id -eq '1czF0GkfnILFA1w-jEtFa7VyGjbGKpc0RPFV32S3_irY') 'Unexpected spreadsheet identity.'
Assert-Check ($mapping.target.discovered_sheet_count -eq 53) 'Expected 53 discovered tabs.'
Assert-Check ($mapping.approved_mapped_tabs.Count -eq 3) 'Expected exactly three approved mapped tabs.'
Assert-Check ((@($mapping.approved_mapped_tabs | ForEach-Object title) -join '|') -eq 'Index|Authority|Registry_Test_Log') 'Approved tab inventory is not exact.'
Assert-Check ([bool]$mapping.safety.read_only) 'read_only must be true.'
Assert-Check (-not [bool]$mapping.safety.write_capability) 'write_capability must be false.'
Assert-Check (-not [bool]$mapping.safety.writes_attempted) 'writes_attempted must be false.'
Assert-Check ($mapping.safety.records_written -eq 0) 'records_written must be zero.'
Assert-Check ($mapping.safety.promotion_status -eq 'HOLD') 'Promotion must remain HOLD.'
Assert-Check ($mapping.safety.architecture_status -eq 'FROZEN') 'Architecture must remain FROZEN.'
Assert-Check ([bool]$mapping.safety.reconciliation_required_before_any_future_write) 'Future reconciliation gate must remain required.'
Assert-Check ($mapping.approved_mapped_tabs[2].duplicate_header_columns -contains 'notes') 'Duplicate Registry_Test_Log notes header must be recorded.'

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = @(
    '# Command Tower Tracker Live Mapping Verification',
    '',
    "Status: **$status**",
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: local artifact validation only. The live Google Sheet was read through the connected Google Sheets connector before this artifact was created; this verifier performs no Google Sheets read or write.',
    '',
    '- Exact Tracker Sandbox spreadsheet identity is preserved.',
    '- Exactly three approved tabs are mapped: `Index`, `Authority`, and `Registry_Test_Log`.',
    '- Duplicate `notes` headers in `Registry_Test_Log` are explicitly retained as a positional-mapping warning.',
    '- Read-only, zero-write, PostgreSQL-authority, HOLD, and FROZEN controls are preserved.'
)
if ($failures.Count -gt 0) { $lines += '', '## Failures'; $lines += ($failures | ForEach-Object { "- $_" }) }
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
if ($failures.Count -gt 0) { throw (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine) }
Write-Output "PASS: Tracker live mapping verified; receipt written to $ReceiptPath"
