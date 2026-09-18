[CmdletBinding()]
param(
    [string]$EvidencePath,
    [string]$AdapterPath,
    [string]$SummaryPath
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($EvidencePath)) { $EvidencePath = Join-Path $PSScriptRoot 'command-tower-view-readback.json' }
if ([string]::IsNullOrWhiteSpace($AdapterPath)) { $AdapterPath = Join-Path $PSScriptRoot 'command-tower-readonly-adapter.json' }
if ([string]::IsNullOrWhiteSpace($SummaryPath)) { $SummaryPath = Join-Path $PSScriptRoot 'command-tower-summary-readback.json' }
$evidence = Get-Content -Raw -LiteralPath $EvidencePath | ConvertFrom-Json
$adapter = Get-Content -Raw -LiteralPath $AdapterPath | ConvertFrom-Json
$summary = Get-Content -Raw -LiteralPath $SummaryPath | ConvertFrom-Json

if ($adapter.mode -ne 'bounded read-only fixture') { throw 'Adapter mode is not bounded read-only fixture.' }
if ($adapter.identity.row_data_included -ne $false) { throw 'Adapter row_data_included must be false.' }
if ($adapter.identity.write_path -ne $false) { throw 'Adapter write_path must be false.' }
if ($adapter.approved_views.Count -ne 8) { throw "Expected 8 approved views; found $($adapter.approved_views.Count)." }

$evidenceNames = @($evidence.views | ForEach-Object { $_.view })
$adapterNames = @($adapter.approved_views | ForEach-Object { $_.view })
if ((Compare-Object $evidenceNames $adapterNames)) { throw 'Adapter view inventory does not match readback evidence.' }
if (@($adapter.approved_views | Where-Object { $_.exists -ne $true -or $_.has_rows -ne $true }).Count -gt 0) {
    throw 'Every adapter view must exist and have rows in the readback evidence.'
}
if ($summary.mode -ne 'bounded aggregate-only readback') { throw 'Summary evidence mode is not aggregate-only.' }
if ($summary.summaries.Count -ne 8) { throw "Expected 8 aggregate summaries; found $($summary.summaries.Count)." }
if ($summary.identity.row_data_included -ne $false -or $summary.identity.write_path -ne $false) { throw 'Summary evidence has an unsafe payload boundary.' }
if ($summary.row_data_exported -ne $false -or $summary.writes_attempted -ne $false) { throw 'Summary evidence does not confirm bounded read-only behavior.' }
if (@($summary.summaries | Where-Object { $_.aggregate_only -ne $true }).Count -gt 0) { throw 'Every summary must be aggregate-only.' }
if ((Compare-Object @($adapter.summary_readback.views | ForEach-Object view) @($summary.summaries | ForEach-Object view))) { throw 'Adapter summary inventory does not match summary evidence.' }

$adapterText = Get-Content -Raw -LiteralPath $AdapterPath
if ($adapterText -match '"columns"\s*:|"rows"\s*:|"row_data"\s*:') { throw 'Adapter contains a raw row or column payload.' }
if ($evidence.row_data_exported -ne $false -or $evidence.writes_attempted -ne $false) { throw 'Source evidence does not confirm bounded read-only behavior.' }

[pscustomobject]@{
    adapter = $adapter.adapter
    role = $adapter.identity.role
    approved_views = $adapter.approved_views.Count
    views_with_rows = @($adapter.approved_views | Where-Object has_rows).Count
    row_data_included = $adapter.identity.row_data_included
    write_path = $adapter.identity.write_path
    source_row_data_exported = $evidence.row_data_exported
    source_writes_attempted = $evidence.writes_attempted
    summary_views = $summary.summaries.Count
    summary_row_data_exported = $summary.row_data_exported
    summary_writes_attempted = $summary.writes_attempted
    status = 'PASS'
} | Format-List


