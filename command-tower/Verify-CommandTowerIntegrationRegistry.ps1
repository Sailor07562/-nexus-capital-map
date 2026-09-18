[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Integration-Registry-Verification.md')
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $Root 'command-tower-integration-registry.json'
if (-not (Test-Path -LiteralPath $path)) { throw "Missing integration registry: $path" }

$registry = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check { param([bool]$Condition, [string]$Message) if (-not $Condition) { [void]$failures.Add($Message) } }

Assert-Check ($registry.schema_version -eq 1) 'Unexpected registry schema version.'
Assert-Check ($registry.registry_id -eq 'NEXUS-COMMAND-TOWER-INTEGRATION-REGISTRY-v1') 'Unexpected registry identity.'
Assert-Check ($registry.authority.semantic_authority -eq 'PostgreSQL') 'PostgreSQL semantic authority is not preserved.'
Assert-Check ($registry.authority.promotion_status -eq 'HOLD') 'Promotion must remain HOLD.'
Assert-Check ($registry.authority.architecture_status -eq 'FROZEN') 'Architecture must remain FROZEN.'
Assert-Check ($registry.surfaces.Count -eq 2) 'Expected exactly two registered downstream surfaces.'

$airtable = @($registry.surfaces | Where-Object { $_.surface_type -eq 'Airtable' })[0]
$tracker = @($registry.surfaces | Where-Object { $_.surface_type -eq 'Google Sheets' })[0]
Assert-Check ($null -ne $airtable) 'Airtable surface is missing.'
Assert-Check ($null -ne $tracker) 'Tracker surface is missing.'
Assert-Check ($airtable.base_id -eq 'appl14dXK5cUtvZt8') 'Unexpected Airtable base identity.'
Assert-Check ($airtable.mapped_objects.Count -eq 5) 'Expected five approved Airtable tables.'
Assert-Check (((@($airtable.mapped_objects | ForEach-Object name) -join '|') -eq 'Dashboard_Status|Governance_Command_Center|Airtable_Readback_Seal_Log|Validation_Log|Nexus_Test_Intake')) 'Airtable table inventory is not exact.'
Assert-Check (($airtable.mapped_objects | ForEach-Object { $_.bounded_read.total_record_count } | Measure-Object -Sum).Sum -eq 25) 'Unexpected bounded Airtable record-count total.'
Assert-Check ($tracker.spreadsheet_id -eq '1czF0GkfnILFA1w-jEtFa7VyGjbGKpc0RPFV32S3_irY') 'Unexpected Tracker spreadsheet identity.'
Assert-Check ($tracker.metadata.discovered_sheet_count -eq 53) 'Expected 53 discovered Tracker tabs.'
Assert-Check ($tracker.mapped_objects.Count -eq 3) 'Expected exactly three approved Tracker tabs.'
Assert-Check (((@($tracker.mapped_objects | ForEach-Object name) -join '|') -eq 'Index|Authority|Registry_Test_Log')) 'Tracker tab inventory is not exact.'
Assert-Check ($tracker.mapped_objects[2].duplicate_header_columns -contains 'notes') 'Duplicate Registry_Test_Log notes header must be preserved.'
Assert-Check ([bool]$registry.safety.read_only) 'read_only must be true.'
Assert-Check (-not [bool]$registry.safety.write_capability) 'write_capability must be false.'
Assert-Check (-not [bool]$registry.safety.writes_attempted) 'writes_attempted must be false.'
Assert-Check ($registry.safety.records_written -eq 0) 'records_written must be zero.'
Assert-Check (-not [bool]$registry.safety.schema_changes) 'schema_changes must be false.'
Assert-Check (-not [bool]$registry.safety.workflow_changes) 'workflow_changes must be false.'
Assert-Check (-not [bool]$registry.safety.credential_changes) 'credential_changes must be false.'
Assert-Check (-not [bool]$registry.safety.trading_or_transfer_actions) 'Trading or transfer actions must be false.'
Assert-Check ([bool]$registry.safety.reconciliation_required_before_any_future_write) 'Future reconciliation gate must remain required.'
Assert-Check (($airtable.mapped_objects | ForEach-Object { $_.mapped_fields.Count } | Measure-Object -Sum).Sum -ge 30) 'Expected bounded Airtable field mapping coverage.'

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = @(
    '# Command Tower Integration Registry Verification',
    '',
    "Status: **$status**",
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: registry artifact validation only. Airtable and Google Sheets were read through their connected read-only discovery/readback paths before this artifact was created; this verifier performs no connector reads or writes.',
    '',
    '- PostgreSQL remains semantic authority.',
    '- Airtable is limited to the five approved sandbox tables and bounded record counts.',
    '- Tracker is limited to the exact `Index`, `Authority`, and `Registry_Test_Log` tabs.',
    '- Duplicate `notes` headers in `Registry_Test_Log` remain an explicit positional-mapping warning.',
    '- No writes, schema changes, workflow changes, credential changes, trading actions, transfers, or promotion actions are included.'
)
if ($failures.Count -gt 0) { $lines += '', '## Failures'; $lines += ($failures | ForEach-Object { "- $_" }) }
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
if ($failures.Count -gt 0) { throw (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine) }
Write-Output "PASS: integration registry verified; receipt written to $ReceiptPath"
