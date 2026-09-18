[CmdletBinding()]
param(
    [string]$HostName = '127.0.0.1',
    [int]$Port = 5432,
    [string]$Database = 'postgres',
    [string]$Role = 'nexus_command_tower_ro',
    [string]$OutputPath,
    [string]$PsqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $PSScriptRoot 'command-tower-summary-readback.json' }
if (-not (Test-Path -LiteralPath $PsqlPath)) { throw "PostgreSQL client not found at $PsqlPath" }
$rolePassword = Read-Host "Password for $Role@$HostName`:$Port/$Database" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($rolePassword)
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
[Environment]::SetEnvironmentVariable('PGPASSWORD', $plainPassword, 'Process')

$queries = [ordered]@{
    'nexus.v_capital_map_operating_summary' = @"
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
    'nexus.v_broker_connection_health' = @"
SELECT count(*) AS connections,
       count(*) FILTER (WHERE live_trading_enabled) AS live_trading_enabled,
       count(*) FILTER (WHERE latest_trading_blocked) AS trading_blocked,
       count(*) FILTER (WHERE latest_transfers_blocked) AS transfers_blocked,
       count(*) FILTER (WHERE latest_account_blocked) AS accounts_blocked
FROM nexus.v_broker_connection_health;
"@
    'nexus.v_automation_intake_queue' = @"
SELECT count(*) AS intake_items,
       count(*) FILTER (WHERE review_state = 'pending') AS pending_review,
       count(*) FILTER (WHERE review_state = 'reviewed') AS reviewed,
       count(*) FILTER (WHERE review_state = 'admitted') AS admitted
FROM nexus.v_automation_intake_queue;
"@
    'nexus.v_research_radar_governance_health' = @"
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
    'nexus.v_research_radar_state_status' = @"
SELECT count(*) AS lanes,
       count(*) FILTER (WHERE scraper_execution_disabled) AS scraper_execution_disabled,
       count(*) FILTER (WHERE thesis_promotion_blocked) AS thesis_promotion_blocked,
       count(*) FILTER (WHERE trade_action_blocked) AS trade_action_blocked,
       COALESCE(sum(pending_signal_count),0) AS pending_signals
FROM nexus.v_research_radar_state_status;
"@
    'nexus.v_paper_order_policy_health' = @"
SELECT count(*) AS policies,
       count(*) FILTER (WHERE live_trading_enabled) AS live_trading_enabled,
       count(*) FILTER (WHERE requires_human_confirmation) AS human_confirmation_required,
       COALESCE(sum(proposal_count),0) AS proposals,
       COALESCE(sum(submitted_order_count),0) AS submitted_orders
FROM nexus.v_paper_order_policy_health;
"@
    'nexus.v_signal_lineage' = @"
SELECT count(*) AS signals,
       count(DISTINCT capital_map_id) AS capital_maps,
       COALESCE(max(pressure_score),0) AS highest_pressure,
       count(*) FILTER (WHERE signal_evidence_id IS NOT NULL) AS evidenced_signals
FROM nexus.v_signal_lineage;
"@
    'nexus.v_shadow_mode_summary' = @"
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

try {
    $summaries = foreach ($view in $queries.Keys) {
        $raw = (& $PsqlPath -X -q -t -A -F '|' -P null='0' -h $HostName -p $Port -U $Role -d $Database -c $queries[$view] 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw "Summary read failed for ${view}: $raw" }
        $values = $raw -split '\|'
        $record = [ordered]@{ view = $view; aggregate_only = $true }
        $index = 0
        $aliases = [regex]::Matches($queries[$view], '(?i)\bAS\s+([a-z_][a-z0-9_]*)') | ForEach-Object { $_.Groups[1].Value }
        foreach ($column in $aliases) {
            if ($index -lt $values.Count) { $record[$column] = [int64]$values[$index] }
            $index++
        }
        [pscustomobject]$record
    }
    $result = [ordered]@{
        captured_at = (Get-Date).ToString('o')
        mode = 'bounded aggregate-only readback'
        identity = [ordered]@{ database = $Database; role = $Role; default_transaction_read_only = $true; row_data_included = $false; write_path = $false }
        summaries = @($summaries)
        source_views = @($queries.Keys)
        row_data_exported = $false
        writes_attempted = $false
    }
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    $result | ConvertTo-Json -Depth 8
}
catch {
    $errorPath = Join-Path (Split-Path -Parent $OutputPath) 'command-tower-summary-readback-error.txt'
    $_ | Out-String | Set-Content -LiteralPath $errorPath -Encoding UTF8
    throw
}
finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $null, 'Process')
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
}


