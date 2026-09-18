param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'postgres-readonly-evidence.json'),
    [string]$PgBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$HostName = '127.0.0.1',
    [int]$Port = 5432,
    [string]$UserName = 'postgres',
    [string]$Database = 'postgres'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Command Tower - PostgreSQL Read-Only Discovery'
$form.Size = New-Object System.Drawing.Size(680, 215)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$label = New-Object System.Windows.Forms.Label
$label.Text = "Enter the PostgreSQL password for '$UserName'. It will not be saved."
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
$statusLabel.Size = New-Object System.Drawing.Size(630, 20)
$statusLabel.ForeColor = [System.Drawing.Color]::DarkRed
$form.Controls.Add($statusLabel)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = 'Run read-only check'
$okButton.Location = New-Object System.Drawing.Point(420, 130)
$okButton.Size = New-Object System.Drawing.Size(140, 30)
$okButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($passwordBox.Text)) { $statusLabel.Text = 'Password is required.'; return }
    $form.Tag = 'OK'; $form.Close()
})
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Location = New-Object System.Drawing.Point(570, 130)
$cancelButton.Size = New-Object System.Drawing.Size(80, 30)
$cancelButton.Add_Click({ $form.Tag = 'Cancel'; $form.Close() })
$form.Controls.Add($cancelButton)
$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton
$null = $form.ShowDialog()
if ($form.Tag -ne 'OK') { throw 'PostgreSQL read-only discovery was canceled.' }

$plainPassword = [string]$passwordBox.Text
$passwordBox.Clear()
$previousPgPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')

function Invoke-Psql([string]$Sql) {
    $result = & (Join-Path $PgBin 'psql.exe') -X -w -qAt -h $HostName -p $Port -U $UserName -d $Database -v ON_ERROR_STOP=1 -F "`t" -c $Sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($result | Out-String).Trim()) }
    return (($result | Out-String).Trim())
}

try {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $plainPassword, 'Process')
    $evidence = [ordered]@{
        captured_at = (Get-Date).ToString('o')
        mode = 'read-only catalog discovery'
        target = [ordered]@{ host = $HostName; port = $Port; database = $Database; requested_user = $UserName }
        identity = Invoke-Psql "SELECT current_database(), current_user, session_user, COALESCE(inet_server_addr()::text,'local'), inet_server_port(), current_setting('server_version');"
        role_attributes = Invoke-Psql "SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin FROM pg_roles WHERE rolname = current_user;"
        transaction_modes = Invoke-Psql "SELECT current_setting('transaction_read_only'), current_setting('default_transaction_read_only');"
        schemas = Invoke-Psql "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('nexus','operations') ORDER BY schema_name;"
        migration_lineage = Invoke-Psql "SELECT CASE WHEN to_regclass('nexus.schema_migrations') IS NULL THEN 'missing' ELSE (SELECT COUNT(*)::text || E'\t' || COALESCE(MAX(version)::text,'') FROM nexus.schema_migrations) END;"
        operations_objects = Invoke-Psql "SELECT table_name FROM information_schema.tables WHERE table_schema='operations' ORDER BY table_name;"
        nexus_views = Invoke-Psql "SELECT table_name FROM information_schema.views WHERE table_schema='nexus' ORDER BY table_name;"
        extensions = Invoke-Psql "SELECT extname, extversion FROM pg_extension ORDER BY extname;"
        read_only_binding_gate = 'blocked until a bounded non-superuser read-only role, target identity, migration lineage, object inventory, and Last Known Good evidence are separately verified'
    }
    $evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Evidence written: $OutputPath"
    $evidence | ConvertTo-Json -Depth 8
}
finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPgPassword, 'Process')
    $plainPassword = $null
}


