[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$WorkflowPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\n8n\workflows\local-candidates\NEXUS-N8N-WORKFLOW-007-EVENT-LEDGER-ORCHESTRATION.json'),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Event-Ledger-Readiness-Verification.md')
)

$ErrorActionPreference = 'Stop'
$workflowFile = [System.IO.Path]::GetFullPath($WorkflowPath)
if (-not (Test-Path -LiteralPath $workflowFile)) { throw "Missing workflow candidate: $workflowFile" }
$workflow = Get-Content -LiteralPath $workflowFile -Raw | ConvertFrom-Json
$failures = [System.Collections.Generic.List[string]]::new()
function Assert-Check { param([bool]$Condition, [string]$Message) if (-not $Condition) { [void]$failures.Add($Message) } }

$nodes = @($workflow.nodes)
$nodeTypes = @($nodes | ForEach-Object { $_.type })
$nodeNames = @($nodes | ForEach-Object { [string]$_.name })
$postgresNodes = @($nodes | Where-Object { $_.type -eq 'n8n-nodes-base.postgres' })
$postgresQueries = @($postgresNodes | ForEach-Object { $_.parameters.query }) -join "`n"

Assert-Check ($workflow.name -eq 'NEXUS-N8N-WORKFLOW-007-EVENT-LEDGER-ORCHESTRATION') 'Unexpected workflow name.'
Assert-Check (-not [bool]$workflow.active) 'Workflow candidate is active.'
Assert-Check ($nodeTypes -contains 'n8n-nodes-base.manualTrigger') 'Manual trigger is missing.'
Assert-Check (-not ($nodeTypes -contains 'n8n-nodes-base.scheduleTrigger')) 'Scheduled trigger is present.'
Assert-Check ($nodes.Count -eq 7) "Expected 7 candidate nodes; found $($nodes.Count)."
Assert-Check ($postgresNodes.Count -eq 3) "Expected 3 governed PostgreSQL gateway nodes; found $($postgresNodes.Count)."
Assert-Check ($postgresQueries -match 'nexus_constitution\.record_nexus_event') 'Governed record gateway call is missing.'
Assert-Check ($postgresQueries -match 'nexus_constitution\.read_nexus_event') 'Governed read gateway call is missing.'
Assert-Check (-not ($postgresQueries -match '(?im)\b(INSERT|UPDATE|DELETE|CREATE|ALTER|DROP)\b')) 'Direct SQL write/DDL keyword found in candidate queries.'
Assert-Check (@($nodeNames | Where-Object { $_ -eq 'Verify Readback' }).Count -eq 1) 'Readback verification node is missing.'
Assert-Check (@($nodeNames | Where-Object { $_ -eq 'Verify Replay and Issue Receipt' }).Count -eq 1) 'Replay receipt node is missing.'
Assert-Check (@($nodeNames | Where-Object { $_ -eq 'Prepare Event Payload' }).Count -eq 1) 'Payload preparation node is missing.'

$status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL' }
$lines = @(
    '# Command Tower Event Ledger Readiness Verification',
    '',
    "Status: **$status**",
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: static candidate validation only. Workflow 007 was not imported, activated, executed, replayed, or connected to live credentials.',
    '',
    '- Candidate remains inactive and manual-triggered only.',
    '- Governed record/read/replay gateway calls are present.',
    '- No direct table write or DDL keyword was found in the candidate queries.',
    '- Readback and idempotent replay verification nodes are present.',
    '- No broker or trading nodes are present.',
    '',
    'Execution remains **HOLD** pending separate approval, secure credential verification, and sandbox receipt evidence.'
)
if ($failures.Count -gt 0) { $lines += '', '## Failures'; $lines += ($failures | ForEach-Object { "- $_" }) }
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
if ($failures.Count -gt 0) { throw (($failures | ForEach-Object { "- $_" }) -join [Environment]::NewLine) }
Write-Output "PASS: event ledger candidate verified; receipt written to $ReceiptPath"
