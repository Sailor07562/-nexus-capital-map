[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Alpaca-Paper-Health-Verification.md')
)

$ErrorActionPreference = 'Stop'
$path = Join-Path $Root 'command-tower-alpaca-paper-health.json'
if (-not (Test-Path -LiteralPath $path)) { throw "Missing Alpaca Paper health projection: $path" }

$health = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check { param([bool]$Condition, [string]$Message) if (-not $Condition) { [void]$failures.Add($Message) } }

Assert-Check ($health.schema_version -eq 1) 'Unexpected health projection schema version.'
Assert-Check ($health.surface_id -eq 'alpaca:paper') 'Unexpected Alpaca Paper surface identity.'
Assert-Check ($health.provider -eq 'Alpaca Paper') 'Unexpected provider identity.'
Assert-Check ($health.binding_status -eq 'projection only; direct broker connector not enabled') 'Direct broker connector boundary changed.'
Assert-Check ($health.source.system -eq 'PostgreSQL') 'PostgreSQL source authority is not preserved.'
Assert-Check ($health.source.role -eq 'nexus_command_tower_ro') 'Unexpected source role.'
Assert-Check ($health.source.source_mode -eq 'approved-bounded-live-readonly') 'Source mode is outside the approved read-only boundary.'
Assert-Check ($health.source.views.Count -eq 3) 'Expected exactly three approved broker/Paper source views.'
Assert-Check (((@($health.source.views) -join '|') -eq 'nexus.v_broker_connection_health|nexus.v_paper_order_policy_health|nexus.v_shadow_mode_summary')) 'Approved Paper health view scope is not exact.'
Assert-Check ($health.health.live_trading_enabled -eq 0) 'Live trading must remain disabled.'
Assert-Check ($health.health.submitted_orders -eq 0) 'Submitted Paper orders must remain zero.'
Assert-Check ($health.health.order_submission_enabled -eq 0) 'Order submission must remain disabled.'
Assert-Check ($health.health.order_submission_attempted -eq 0) 'Order submission attempts must remain zero.'
Assert-Check ([bool]$health.safety.read_only) 'read_only must be true.'
Assert-Check (-not [bool]$health.safety.write_capability) 'write_capability must be false.'
Assert-Check (-not [bool]$health.safety.row_data_exported) 'row_data_exported must be false.'
Assert-Check (-not [bool]$health.safety.writes_attempted) 'writes_attempted must be false.'
Assert-Check (-not [bool]$health.safety.direct_alpaca_connector_used) 'Direct Alpaca connector must remain unused.'
Assert-Check (-not [bool]$health.safety.order_submission_enabled) 'Safety order_submission_enabled must be false.'
Assert-Check (-not [bool]$health.safety.order_submission_attempted) 'Safety order_submission_attempted must be false.'
Assert-Check (-not [bool]$health.safety.live_trading_enabled) 'Safety live_trading_enabled must be false.'
Assert-Check ([bool]$health.safety.human_confirmation_required) 'Human confirmation must remain required.'
Assert-Check ($health.safety.promotion_status -eq 'HOLD') 'Promotion must remain HOLD.'
Assert-Check ($health.safety.architecture_status -eq 'FROZEN') 'Architecture must remain FROZEN.'

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = @(
    '# Command Tower Alpaca Paper Health Verification',
    '',
    "Status: **$status**",
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: aggregate-only Paper health projection from the approved PostgreSQL read-only adapter. No direct Alpaca connector, credential, order, transfer, or trading action is included.',
    '',
    '- Live trading is disabled and submitted orders remain zero.',
    '- Order submission is disabled and no submission attempt was observed.',
    '- Human confirmation remains required for any future Paper order proposal.',
    '- Row export, writes, direct Alpaca connector use, and promotion remain disabled.'
)
if ($failures.Count -gt 0) { $lines += '', '## Failures'; $lines += ($failures | ForEach-Object { "- $_" }) }
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
if ($failures.Count -gt 0) { throw (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine) }
Write-Output "PASS: Alpaca Paper health projection verified; receipt written to $ReceiptPath"
