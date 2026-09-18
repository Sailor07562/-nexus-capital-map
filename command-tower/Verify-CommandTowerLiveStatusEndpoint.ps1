[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path),
    [string]$PayloadPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'command-tower-live-status-payload.json'),
    [string]$ReceiptPath = (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'CommandTower-Live-Status-Endpoint-Verification.md')
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $PayloadPath)) { throw "Missing live status payload: $PayloadPath" }
$output = & node (Join-Path $Root 'Serve-CommandTowerStatus.mjs') --self-test --payload $PayloadPath 2>&1
if ($LASTEXITCODE -ne 0) { throw (($output | Out-String).Trim()) }

$lines = @(
    '# Command Tower Live Status Endpoint Verification',
    '',
    'Status: **PASS**',
    "Captured: $((Get-Date).ToString('o'))",
    '',
    'Scope: local loopback self-test using the approved bounded live scalar payload. The endpoint exposes GET-only health/status responses, rejects write methods, and does not connect the browser directly to PostgreSQL.',
    '',
    '- `GET /healthz` returned the approved live read-only mode.',
    '- `GET /status` returned eight aggregate summaries.',
    '- Row export, writes, and write capability remained false.',
    '- `POST /status` was rejected with HTTP 405.',
    '- Unknown paths were rejected with HTTP 404.',
    '- Promotion remains HOLD and architecture remains FROZEN.'
)
Set-Content -LiteralPath $ReceiptPath -Value $lines -Encoding UTF8
Write-Output "PASS: live status endpoint verified; receipt written to $ReceiptPath"
