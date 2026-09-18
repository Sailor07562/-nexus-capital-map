[CmdletBinding()]
param(
    [string]$HostName = '127.0.0.1',
    [int]$Port = 5432,
    [string]$Database = 'postgres',
    [string]$Role = 'nexus_command_tower_ro',
    [int]$ExpectedMigration = 262,
    [string]$OutputPath,
    [string]$PsqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $PSScriptRoot 'command-tower-migration-object-evidence.json' }
if (-not (Test-Path -LiteralPath $PsqlPath)) { throw "PostgreSQL client not found at $PsqlPath" }

$approvedViews = @(
    'nexus.v_capital_map_operating_summary',
    'nexus.v_broker_connection_health',
    'nexus.v_automation_intake_queue',
    'nexus.v_research_radar_governance_health',
    'nexus.v_research_radar_state_status',
    'nexus.v_paper_order_policy_health',
    'nexus.v_signal_lineage',
    'nexus.v_shadow_mode_summary'
)

$securePassword = Read-Host "Password for $Role@$HostName`:$Port/$Database" -AsSecureString
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
$plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
$previousPgPassword = [Environment]::GetEnvironmentVariable('PGPASSWORD', 'Process')

function Invoke-Psql([string]$Sql) {
    $result = & $PsqlPath -X -w -qAt -h $HostName -p $Port -U $Role -d $Database -v ON_ERROR_STOP=1 -F "`t" -c $Sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw (($result | Out-String).Trim()) }
    return (($result | Out-String).Trim())
}

try {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $plainPassword, 'Process')
    $identity = Invoke-Psql "SELECT current_database(), current_user, session_user, current_setting('transaction_read_only'), current_setting('default_transaction_read_only'), current_setting('server_version');"
    $schemaMigrationsExists = (Invoke-Psql "SELECT to_regclass('nexus.schema_migrations') IS NOT NULL;") -eq 't'
    if (-not $schemaMigrationsExists) { throw 'nexus.schema_migrations is missing.' }

    $columnRaw = Invoke-Psql "SELECT column_name FROM information_schema.columns WHERE table_schema='nexus' AND table_name='schema_migrations' ORDER BY ordinal_position;"
    $migrationColumns = @($columnRaw -split "`r?`n" | Where-Object { $_ })
    if ('version' -notin $migrationColumns) { throw 'nexus.schema_migrations has no version column.' }

    $lineageRaw = Invoke-Psql "SELECT COUNT(*)::text, COALESCE(MAX(version)::text,''), COALESCE(MIN(version)::text,'') FROM nexus.schema_migrations;"
    $lineageValues = $lineageRaw -split "`t"
    $migrationCount = [int64]$lineageValues[0]
    $maxMigration = [int64]$lineageValues[1]
    $minMigration = [int64]$lineageValues[2]

    $checksumColumn = if ('checksum' -in $migrationColumns) { 'checksum' } elseif ('sha256' -in $migrationColumns) { 'sha256' } else { $null }
    $checksumPresent = $null -ne $checksumColumn
    $checksumCount = 0
    $checksumDigest = $null
    if ($checksumPresent) {
        $checksumRaw = Invoke-Psql "SELECT COUNT(*) FILTER (WHERE $checksumColumn IS NOT NULL AND $checksumColumn::text <> '')::text, COALESCE(md5(string_agg(version::text || ':' || $checksumColumn::text, '|' ORDER BY version)), md5('')) FROM nexus.schema_migrations;"
        $checksumValues = $checksumRaw -split "`t"
        $checksumCount = [int64]$checksumValues[0]
        $checksumDigest = $checksumValues[1]
    }

    $valuesSql = ($approvedViews | ForEach-Object { "('$($_.Replace("'", "''"))')" }) -join ','
    $objectRaw = Invoke-Psql "WITH approved(view_name) AS (VALUES $valuesSql) SELECT a.view_name, CASE WHEN c.oid IS NULL THEN 'missing' ELSE 'present' END, COALESCE(c.relkind::text,''), COALESCE(md5(pg_get_viewdef(c.oid, true)), '') FROM approved a LEFT JOIN pg_class c ON c.oid = to_regclass(a.view_name) ORDER BY a.view_name;"
    $objects = foreach ($line in @($objectRaw -split "`r?`n" | Where-Object { $_ })) {
        $parts = $line -split "`t", 4
        [ordered]@{ view = $parts[0]; status = $parts[1]; relkind = $parts[2]; definition_md5 = $parts[3] }
    }

    $objectPresentCount = @($objects | Where-Object { $_.status -eq 'present' }).Count
    $objectDefinitionHashCount = @($objects | Where-Object { $_.status -eq 'present' -and $_.definition_md5 }).Count
    $checksumPass = $checksumPresent -and $checksumCount -eq $migrationCount -and $maxMigration -eq $ExpectedMigration
    $objectPass = $objectPresentCount -eq $approvedViews.Count -and $objectDefinitionHashCount -eq $approvedViews.Count
    $status = if ($checksumPass -and $objectPass) { 'PASS' } else { 'BLOCKED' }

    $evidence = [ordered]@{
        captured_at = (Get-Date).ToString('o')
        mode = 'bounded read-only migration and approved-object verification'
        target = [ordered]@{ host = $HostName; port = $Port; database = $Database; schema = 'nexus'; role = $Role }
        identity = $identity
        migration_lineage = [ordered]@{
            registry = 'nexus.schema_migrations'
            columns = $migrationColumns
            row_count = $migrationCount
            minimum_version = $minMigration
            maximum_version = $maxMigration
            expected_maximum_version = $ExpectedMigration
            checksum_column_present = $checksumPresent
            checksum_column = $checksumColumn
            checksum_count = $checksumCount
            checksum_digest = $checksumDigest
            checksum_gate = if ($checksumPass) { 'PASS' } else { 'BLOCKED' }
        }
        approved_objects = $objects
        object_gate = if ($objectPass) { 'PASS' } else { 'BLOCKED' }
        row_data_exported = $false
        writes_attempted = $false
        schema_or_data_changed = $false
        migrations_changed = $false
        status = $status
    }
    $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    $evidence | ConvertTo-Json -Depth 10
}
finally {
    [Environment]::SetEnvironmentVariable('PGPASSWORD', $previousPgPassword, 'Process')
    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    $plainPassword = $null
}


