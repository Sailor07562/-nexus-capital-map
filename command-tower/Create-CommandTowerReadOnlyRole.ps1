param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'command-tower-role-creation-evidence.json'),
    [string]$PgBin = 'C:\Program Files\PostgreSQL\18\bin',
    [string]$HostName = '127.0.0.1',
    [int]$Port = 5432,
    [string]$AdminUser = 'postgres',
    [string]$Database = 'postgres',
    [string]$RoleName = 'nexus_command_tower_ro'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Command Tower - Create Bounded Read-Only Role'
$form.Size = New-Object System.Drawing.Size(720, 300)
$form.StartPosition = 'CenterScreen'
$form.TopMost = $true
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$adminLabel = New-Object System.Windows.Forms.Label
$adminLabel.Text = "Existing PostgreSQL admin password ('$AdminUser')"
$adminLabel.Location = New-Object System.Drawing.Point(20, 20)
$adminLabel.Size = New-Object System.Drawing.Size(660, 25)
$form.Controls.Add($adminLabel)

$adminBox = New-Object System.Windows.Forms.TextBox
$adminBox.Location = New-Object System.Drawing.Point(20, 48)
$adminBox.Size = New-Object System.Drawing.Size(660, 25)
$adminBox.UseSystemPasswordChar = $true
$form.Controls.Add($adminBox)

$roleLabel = New-Object System.Windows.Forms.Label
$roleLabel.Text = "New password for '$RoleName' (not saved)"
$roleLabel.Location = New-Object System.Drawing.Point(20, 88)
$roleLabel.Size = New-Object System.Drawing.Size(660, 25)
$form.Controls.Add($roleLabel)

$roleBox = New-Object System.Windows.Forms.TextBox
$roleBox.Location = New-Object System.Drawing.Point(20, 116)
$roleBox.Size = New-Object System.Drawing.Size(660, 25)
$roleBox.UseSystemPasswordChar = $true
$form.Controls.Add($roleBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 152)
$statusLabel.Size = New-Object System.Drawing.Size(660, 35)
$statusLabel.ForeColor = [System.Drawing.Color]::DarkRed
$form.Controls.Add($statusLabel)

$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = 'Create and verify'
$okButton.Location = New-Object System.Drawing.Point(500, 205)
$okButton.Size = New-Object System.Drawing.Size(115, 30)
$okButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($adminBox.Text) -or [string]::IsNullOrWhiteSpace($roleBox.Text)) {
        $statusLabel.Text = 'Both passwords are required.'
        return
    }
    if ($roleBox.Text.Length -lt 12) {
        $statusLabel.Text = 'Use a new role password with at least 12 characters.'
        return
    }
    $form.Tag = 'OK'; $form.Close()
})
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Location = New-Object System.Drawing.Point(625, 205)
$cancelButton.Size = New-Object System.Drawing.Size(70, 30)
$cancelButton.Add_Click({ $form.Tag = 'Cancel'; $form.Close() })
$form.Controls.Add($cancelButton)
$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton
$null = $form.ShowDialog()
if ($form.Tag -ne 'OK') { throw 'Role creation was canceled.' }

$adminPassword = [string]$adminBox.Text
$rolePassword = [string]$roleBox.Text
$adminBox.Clear(); $roleBox.Clear()
$previousPgPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')

function Invoke-Psql([string]$UserName, [string]$Password, [string]$Sql) {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $Password, 'Process')
    $result = $Sql | & (Join-Path $PgBin 'psql.exe') -X -w -qAt -h $HostName -p $Port -U $UserName -d $Database -v ON_ERROR_STOP=1 -F "`t" -f - 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($result | Out-String).Trim()) }
    return (($result | Out-String).Trim())
}

try {
    $roleExists = Invoke-Psql $AdminUser $adminPassword "SELECT COUNT(*) FROM pg_roles WHERE rolname = '$RoleName';"
    if ($roleExists.Trim() -ne '0') { throw "Role '$RoleName' already exists; no alteration was attempted." }

    $schemaExists = Invoke-Psql $AdminUser $adminPassword "SELECT COUNT(*) FROM pg_namespace WHERE nspname = 'nexus';"
    if ($schemaExists.Trim() -ne '1') { throw "Required schema 'nexus' was not found; no role was created." }

    $escapedRolePassword = $rolePassword.Replace("'", "''")
    $createSql = @"
CREATE ROLE $RoleName LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS PASSWORD '$escapedRolePassword';
ALTER ROLE $RoleName SET default_transaction_read_only = on;
GRANT CONNECT ON DATABASE $Database TO $RoleName;
GRANT USAGE ON SCHEMA nexus TO $RoleName;
REVOKE CREATE ON SCHEMA nexus FROM $RoleName;
GRANT SELECT ON ALL TABLES IN SCHEMA nexus TO $RoleName;
"@
    Invoke-Psql $AdminUser $adminPassword $createSql | Out-Null

    $adminVerification = Invoke-Psql $AdminUser $adminPassword @"
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolreplication, rolbypassrls
FROM pg_roles WHERE rolname = '$RoleName';
SELECT has_database_privilege('$RoleName', '$Database', 'CONNECT');
SELECT has_schema_privilege('$RoleName', 'nexus', 'USAGE');
SELECT has_schema_privilege('$RoleName', 'nexus', 'CREATE');
SELECT has_table_privilege('$RoleName', 'nexus.schema_migrations', 'SELECT');
SELECT has_table_privilege('$RoleName', 'nexus.schema_migrations', 'INSERT');
SELECT has_table_privilege('$RoleName', 'nexus.schema_migrations', 'UPDATE');
SELECT has_table_privilege('$RoleName', 'nexus.schema_migrations', 'DELETE');
"@

    $roleSession = Invoke-Psql $RoleName $rolePassword "SELECT current_database(), current_user, session_user, current_setting('transaction_read_only'), current_setting('default_transaction_read_only');"
    $evidence = [ordered]@{
        captured_at = (Get-Date).ToString('o')
        action = 'created bounded PostgreSQL read-only role'
        target = [ordered]@{ host = $HostName; port = $Port; database = $Database; role = $RoleName }
        grants_applied = @('CONNECT on database', 'USAGE on nexus schema', 'SELECT on existing nexus tables', 'default_transaction_read_only=on')
        default_privileges_changed = $false
        schema_or_data_changed = $false
        migration_or_workflow_changed = $false
        admin_verification = $adminVerification
        role_session_verification = $roleSession
        secrets_persisted = $false
    }
    $evidence | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    Write-Output "Evidence written: $OutputPath"
    $evidence | ConvertTo-Json -Depth 8
}
finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPgPassword, 'Process')
    $adminPassword = $null
    $rolePassword = $null
    $escapedRolePassword = $null
}


