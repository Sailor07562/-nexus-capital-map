[CmdletBinding()]
param(
    [string]$HostName = '127.0.0.1',
    [int]$Port = 5432,
    [string]$Database = 'postgres',
    [string]$Schema = 'nexus',
    [string]$Role = 'nexus_command_tower_ro',
    [string]$OutputPath = (Join-Path $PSScriptRoot 'command-tower-live-status-payload.json'),
    [string]$PsqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $PsqlPath)) { throw "PostgreSQL client not found at $PsqlPath" }

$approvedViews = @(
    'v_capital_map_operating_summary',
    'v_broker_connection_health',
    'v_automation_intake_queue',
    'v_research_radar_governance_health',
    'v_research_radar_state_status',
    'v_paper_order_policy_health',
    'v_signal_lineage',
    'v_shadow_mode_summary'
)

$queries = [ordered]@{
    'v_capital_map_operating_summary' = @"
SELECT count(*) AS records,
       COALESCE(sum(active_signal_count),0) AS active_signals,
       COALESCE(sum(active_constraint_count),0) AS active_constraints,
       COALESCE(sum(capital_flow_count),0) AS capital_flows,
       COALESCE(sum(company_exposure_count),0) AS company_exposures,
       COALESCE(sum(current_decision_count),0) AS current_decisions,
       COALESCE(sum(open_outcome_count),0) AS open_outcomes,
       COALESCE(max(highest_active_pressure_score),0) AS highest_pressure
FROM nexus.v_capital_map_operating_summary;
"@
    'v_broker_connection_health' = @"
SELECT count(*) AS connections,
       count(*) FILTER (WHERE live_trading_enabled) AS live_trading_enabled,
       count(*) FILTER (WHERE latest_trading_blocked) AS trading_blocked,
       count(*) FILTER (WHERE latest_transfers_blocked) AS transfers_blocked,
       count(*) FILTER (WHERE latest_account_blocked) AS accounts_blocked
FROM nexus.v_broker_connection_health;
"@
    'v_automation_intake_queue' = @"
SELECT count(*) AS intake_items,
       count(*) FILTER (WHERE review_state = 'pending') AS pending_review,
       count(*) FILTER (WHERE review_state = 'reviewed') AS reviewed,
       count(*) FILTER (WHERE review_state = 'admitted') AS admitted
FROM nexus.v_automation_intake_queue;
"@
    'v_research_radar_governance_health' = @"
SELECT COALESCE(max(state_lane_count),0) AS state_lanes,
       COALESCE(max(source_count),0) AS sources,
       COALESCE(max(pending_signal_count),0) AS pending_signals,
       COALESCE(max(lane_control_violation_count),0) AS lane_violations,
       COALESCE(max(source_control_violation_count),0) AS source_violations,
       COALESCE(max(signal_control_violation_count),0) AS signal_violations,
       COALESCE(max(scraper_control_violation_count),0) AS scraper_violations,
       COALESCE(max(ticker_link_control_violation_count),0) AS ticker_link_violations
FROM nexus.v_research_radar_governance_health;
"@
    'v_research_radar_state_status' = @"
SELECT count(*) AS lanes,
       count(*) FILTER (WHERE scraper_execution_disabled) AS scraper_execution_disabled,
       count(*) FILTER (WHERE thesis_promotion_blocked) AS thesis_promotion_blocked,
       count(*) FILTER (WHERE trade_action_blocked) AS trade_action_blocked,
       COALESCE(sum(pending_signal_count),0) AS pending_signals
FROM nexus.v_research_radar_state_status;
"@
    'v_paper_order_policy_health' = @"
SELECT count(*) AS policies,
       count(*) FILTER (WHERE live_trading_enabled) AS live_trading_enabled,
       count(*) FILTER (WHERE requires_human_confirmation) AS human_confirmation_required,
       COALESCE(sum(proposal_count),0) AS proposals,
       COALESCE(sum(submitted_order_count),0) AS submitted_orders
FROM nexus.v_paper_order_policy_health;
"@
    'v_signal_lineage' = @"
SELECT count(*) AS signals,
       count(DISTINCT capital_map_id) AS capital_maps,
       COALESCE(max(pressure_score),0) AS highest_pressure,
       count(*) FILTER (WHERE signal_evidence_id IS NOT NULL) AS evidenced_signals
FROM nexus.v_signal_lineage;
"@
    'v_shadow_mode_summary' = @"
SELECT count(*) AS experiments,
       COALESCE(sum(intent_count),0) AS intents,
       COALESCE(sum(observed_intent_count),0) AS observed_intents,
       COALESCE(sum(eligible_intent_count),0) AS eligible_intents,
       COALESCE(sum(blocked_intent_count),0) AS blocked_intents,
       count(*) FILTER (WHERE sends_orders) AS sends_orders_enabled,
       count(*) FILTER (WHERE any_order_submission_enabled) AS order_submission_enabled,
       count(*) FILTER (WHERE any_order_submission_attempted) AS order_submission_attempted
FROM nexus.v_shadow_mode_summary;
"@
}

$rolePassword = Read-Host "Password for $Role@$HostName`:$Port/$Database" -AsSecureString
$bstr = [IntPtr]::Zero
$previousPgPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')

function Invoke-ReadOnlyPsql([string]$Sql) {
    $readOnlySql = "BEGIN; SET TRANSACTION READ ONLY; $Sql; COMMIT;"
    $result = $readOnlySql | & $PsqlPath -X -w -qAt -F '|' -P null='' -h $HostName -p $Port -U $Role -d $Database -v ON_ERROR_STOP=1 -f - 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($result | Out-String).Trim()) }
    return (($result | Out-String).Trim())
}

try {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($rolePassword)
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $plainPassword, 'Process')
    $rolePassword = $null
    $plainPassword = $null

    $identityParts = (Invoke-ReadOnlyPsql "SELECT current_database(), current_user, current_setting('transaction_read_only'), current_setting('default_transaction_read_only');") -split '\|'
    if ($identityParts.Count -lt 4) { throw 'Live identity readback was incomplete.' }
    if ($identityParts[0] -ne $Database -or $identityParts[1] -ne $Role) { throw "Live identity mismatch: $($identityParts -join '|')" }
    if ($identityParts[2] -ne 'on' -or $identityParts[3] -ne 'on') { throw "Read-only transaction gate failed: $($identityParts -join '|')" }

    $summaries = foreach ($view in $approvedViews) {
        $raw = Invoke-ReadOnlyPsql $queries[$view]
        $values = $raw -split '\|'
        $aliases = [regex]::Matches($queries[$view], '(?i)\bAS\s+([a-z_][a-z0-9_]*)') | ForEach-Object { $_.Groups[1].Value }
        $record = [ordered]@{ view = "$Schema.$view"; aggregate_only = $true }
        for ($index = 0; $index -lt $aliases.Count; $index++) {
            if ($index -ge $values.Count) { throw "Aggregate result incomplete for $view." }
            $record[$aliases[$index]] = [int64]$values[$index]
        }
        [pscustomobject]$record
    }

    $payload = [ordered]@{
        schema_version = 1
        captured_at = (Get-Date).ToString('o')
        source_mode = 'approved-bounded-live-readonly'
        target = [ordered]@{ host = $HostName; port = $Port; database = $Database; schema = $Schema; role = $Role }
        read_only = $true
        view_count = $approvedViews.Count
        summary_count = $summaries.Count
        summaries = @($summaries)
        row_data_exported = $false
        writes_attempted = $false
        write_capability = $false
        gates = [ordered]@{
            identity = 'PASS'
            transaction_read_only = 'PASS'
            approved_view_scope = 'PASS'
            aggregate_only = 'PASS'
        }
        promotion_state = 'HOLD'
        architecture_state = 'FROZEN'
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    $payload | ConvertTo-Json -Depth 10
}
finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPgPassword, 'Process')
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $rolePassword = $null
    $plainPassword = $null
}
