param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'command-tower-view-readback.json'),
    [string]$PgBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$HostName = '127.0.0.1',
    [int]$Port = 5432,
    [string]$RoleName = 'nexus_command_tower_ro',
    [string]$Database = 'postgres'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Command Tower - Read-Only View Readback'
$form.Size = New-Object System.Drawing.Size(680, 210)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter the password for '$RoleName'. No row data will be exported."
$label.Location = New-Object System.Drawing.Point(20, 20)
$label.Size = New-Object System.Drawing.Size(630, 30)
$form.Controls.Add($label)

$passwordBox = New-Object System.Windows.Forms.TextBox
$passwordBox.Location = New-Object System.Drawing.Point(20, 58)
$passwordBox.Size = New-Object System.Drawing.Size(630, 25)
$passwordBox.UseSystemPasswordChar = $true
$form.Controls.Add($passwordBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 92)
$statusLabel.Size = New-Object System.Drawing.Size(630, 25)
$statusLabel.ForeColor = [System.Drawing.Color]::DarkRed
$form.Controls.Add($statusLabel)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = 'Read approved views'
$okButton.Location = New-Object System.Drawing.Point(470, 130)
$okButton.Size = New-Object System.Drawing.Size(140, 30)
$okButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($passwordBox.Text)) { $statusLabel.Text = 'Password is required.'; return }
    $form.Tag = 'OK'; $form.Close()
})
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Location = New-Object System.Drawing.Point(620, 130)
$cancelButton.Size = New-Object System.Drawing.Size(60, 30)
$cancelButton.Add_Click({ $form.Tag = 'Cancel'; $form.Close() })
$form.Controls.Add($cancelButton)
$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton
$null = $form.ShowDialog()
if ($form.Tag -ne 'OK') { throw 'View readback was canceled.' }

$rolePassword = [string]$passwordBox.Text
$passwordBox.Clear()
$previousPgPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')

function Invoke-Psql([string]$Sql) {
    $result = $Sql | & (Join-Path $PgBin 'psql.exe') -X -w -qAt -h $HostName -p $Port -U $RoleName -d $Database -v ON_ERROR_STOP=1 -F ([char]9) -f - 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($result | Out-String).Trim()) }
    return (($result | Out-String).Trim())
}

try {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $rolePassword, 'Process')
    $identity = Invoke-Psql "SELECT current_database(), current_user, current_setting('transaction_read_only'), current_setting('default_transaction_read_only');"
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
    $readback = @()
    foreach ($view in $approvedViews) {
        $safeView = $view.Replace("'", "''")
        $exists = Invoke-Psql "SELECT EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema='nexus' AND table_name='$safeView');"
        $columns = Invoke-Psql "SELECT column_name || ':' || data_type FROM information_schema.columns WHERE table_schema='nexus' AND table_name='$safeView' ORDER BY ordinal_position;"
        $hasRows = if ($exists.Trim() -eq 't') { Invoke-Psql "SELECT EXISTS (SELECT 1 FROM nexus.$view LIMIT 1);" } else { 'not_checked' }
        $readback += [ordered]@{ view = "nexus.$view"; exists = $exists.Trim(); has_rows = $hasRows.Trim(); columns = @($columns -split '\r?\n' | Where-Object { $_ }) }
    }
    $evidence = [ordered]@{
        captured_at = (Get-Date).ToString('o')
        mode = 'bounded read-only view readback'
        identity = $identity
        views = $readback
        row_data_exported = $false
        writes_attempted = $false
    }
    $evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Evidence written: $OutputPath"
    $evidence | ConvertTo-Json -Depth 8
}
finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPgPassword, 'Process')
    $rolePassword = $null
}


