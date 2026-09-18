[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Status-Endpoint-Verification.md')
)

$ErrorActionPreference = 'Stop'
$output = & node (Join-Path $Root 'Serve-CommandTowerStatus.mjs') --self-test --payload (Join-Path $Root 'command-tower-status-payload.json') 2>&1
if ($LASTEXITCODE -ne 0) { throw (($output | Out-String).Trim()) }

$lines = @(
    '# Command Tower Local Status Endpoint Verification',
    '',
    'Status: **PASS**',
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: local self-test only. The endpoint reads the checked-in scalar fixture and binds to loopback when run. No PostgreSQL connection, schema/data change, migration, connector write, workflow execution, promotion, or trading action was performed.',
    '',
    '- `GET /healthz` returned a read-only health response.',
    '- `GET /status` returned eight approved views and eight aggregate summaries.',
    '- Row export, write attempts, and write capability remained false.',
    '- `POST /status` was rejected with HTTP 405.',
    '- Unknown paths were rejected with HTTP 404.',
    '',
    'This is a local fixture-backed status endpoint, not a live database adapter or production service.'
)
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
Write-Output "PASS: local status endpoint verified; receipt written to $ReceiptPath"
