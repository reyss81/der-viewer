<#
.SYNOPSIS
    Automated PostgreSQL to Mermaid ERD Extractor for DER-Viewer.
.DESCRIPTION
    Connects to PostgreSQL, extracts tables, columns, PKs, FKs, and UKs,
    and automatically formats them into a clean, normalized Mermaid .mmd file
    compatible with DER-Viewer.
.EXAMPLE
    .\extract-pg-der.ps1 -Host "localhost" -Port 5432 -User "postgres" -Database "saas_platform" -Schemas "auth","tenants","billing","projects","audit" -OutputFile "..\diagrams\demo_saas_platform.mmd"
#>

param(
    [string]$HostName = "localhost",
    [int]$Port = 5432,
    [string]$User = "postgres",
    [string]$Database = "postgres",
    [string[]]$Schemas = @(),
    [string]$OutputFile = "diagram.mmd",
    [string]$PsqlPath = "psql"
)

$ErrorActionPreference = "Stop"

Write-Host "🔍 Extrayendo metadatos de PostgreSQL [$Database @ $HostName:$Port]..." -ForegroundColor Cyan

$schemaFilter = ""
if ($Schemas.Count -gt 0) {
    $quotedSchemas = ($Schemas | ForEach-Object { "'$_'" }) -join ","
    $schemaFilter = "AND table_schema IN ($quotedSchemas)"
} else {
    $schemaFilter = "AND table_schema NOT IN ('pg_catalog', 'information_schema')"
}

# 1. Query Columns
$sqlCols = @"
SELECT table_schema || '.' || table_name AS full_table, 
       column_name, 
       data_type, 
       udt_name,
       is_nullable
FROM information_schema.columns
WHERE 1=1 $schemaFilter
ORDER BY table_schema, table_name, ordinal_position;
"@

# 2. Query Constraints (PK, UK)
$sqlConstraints = @"
SELECT tc.table_schema || '.' || tc.table_name AS full_table, 
       tc.constraint_type, 
       kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE') $schemaFilter;
"@

# 3. Query Foreign Keys
$sqlFks = @"
SELECT tc.table_schema || '.' || tc.table_name AS source_table, 
       kcu.column_name AS source_col,
       ccu.table_schema || '.' || ccu.table_name AS target_table,
       ccu.column_name AS target_col
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' $schemaFilter
ORDER BY tc.table_schema, tc.table_name, kcu.ordinal_position;
"@

# Helper to execute PSQL query returning pipe-delimited output
function Run-Psql([string]$query) {
    $cmd = "& `"$PsqlPath`" -h `"$HostName`" -p $Port -U `"$User`" -d `"$Database`" -A -F `"|`" -t -c `"$query`""
    return Invoke-Expression $cmd
}

try {
    $rawCols = Run-Psql $sqlCols
    $rawConstraints = Run-Psql $sqlConstraints
    $rawFks = Run-Psql $sqlFks
} catch {
    Write-Error "Error ejecutando psql: $_"
    exit 1
}

# Parse Constraints Map
$pkMap = @{}
$ukMap = @{}
foreach ($line in $rawConstraints) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split('|')
    if ($parts.Count -ge 3) {
        $tbl = $parts[0].Trim()
        $ctype = $parts[1].Trim()
        $col = $parts[2].Trim()
        $key = "$tbl.$col"
        if ($ctype -eq "PRIMARY KEY") { $pkMap[$key] = $true }
        if ($ctype -eq "UNIQUE") { $ukMap[$key] = $true }
    }
}

# Parse FK Map
$fkMap = @{}
$relationships = [System.Collections.Generic.List[string]]::new()
$seenRel = @{}

foreach ($line in $rawFks) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split('|')
    if ($parts.Count -ge 4) {
        $srcTbl = $parts[0].Trim()
        $srcCol = $parts[1].Trim()
        $tgtTbl = $parts[2].Trim()
        $tgtCol = $parts[3].Trim()

        $fkMap["$srcTbl.$srcCol"] = $true

        $srcAlias = $srcTbl.Replace('.', '_')
        $tgtAlias = $tgtTbl.Replace('.', '_')
        
        $relKey = "$tgtAlias->$srcAlias:$srcCol"
        if (-not $seenRel[$relKey]) {
            $seenRel[$relKey] = $true
            $relationships.Add("    $tgtAlias ||--o{ $srcAlias : `"$srcCol`"")
        }
    }
}

# Parse Columns & Group by Table
$tables = @{}
foreach ($line in $rawCols) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split('|')
    if ($parts.Count -ge 5) {
        $tbl = $parts[0].Trim()
        $col = $parts[1].Trim()
        $type = $parts[2].Trim()
        $udt = $parts[3].Trim()

        if (-not $tables.ContainsKey($tbl)) {
            $tables[$tbl] = [System.Collections.Generic.List[psobject]]::new()
        }

        # Normalize data type name for Mermaid
        $cleanType = switch -Wildcard ($type) {
            "*uuid*" { "uuid" }
            "*character varying*" { "varchar" }
            "*text*" { "text" }
            "*integer*" { "int" }
            "*bigint*" { "bigint" }
            "*numeric*" { "numeric" }
            "*boolean*" { "boolean" }
            "*timestamp with time zone*" { "timestamptz" }
            "*timestamp without time zone*" { "timestamp" }
            "*jsonb*" { "jsonb" }
            "*bytea*" { "bytea" }
            Default { $udt }
        }

        $tag = ""
        $key = "$tbl.$col"
        $isPk = $pkMap.ContainsKey($key)
        $isFk = $fkMap.ContainsKey($key)
        $isUk = $ukMap.ContainsKey($key)

        if ($isPk -and $isFk) { $tag = "PK_FK" }
        elseif ($isPk) { $tag = "PK" }
        elseif ($isFk) { $tag = "FK" }
        elseif ($isUk) { $tag = "UK" }

        $tables[$tbl].Add([PSCustomObject]@{
            Column = $col
            Type = $cleanType
            Tag = $tag
        })
    }
}

# Generate Mermaid Code
$sb = [System.Text.StringBuilder]::new()
[void]$sb.AppendLine("erDiagram")

foreach ($tbl in ($tables.Keys | Sort-Object)) {
    $alias = $tbl.Replace('.', '_')
    [void]$sb.AppendLine("    $alias[`"$tbl`"] {")
    foreach ($c in $tables[$tbl]) {
        if ([string]::IsNullOrEmpty($c.Tag)) {
            [void]$sb.AppendLine("        $($c.Type) $($c.Column)")
        } else {
            [void]$sb.AppendLine("        $($c.Type) $($c.Column) $($c.Tag)")
        }
    }
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("")
}

foreach ($rel in $relationships) {
    [void]$sb.AppendLine($rel)
}

$mermaidCode = $sb.ToString()
[System.IO.File]::WriteAllText($OutputFile, $mermaidCode, [System.Text.Encoding]::UTF8)

Write-Host "✅ Diagrama generado con éxito en: $OutputFile" -ForegroundColor Green
Write-Host "📊 Tablas procesadas: $($tables.Count)" -ForegroundColor Gray
Write-Host "🔗 Relaciones detectadas: $($relationships.Count)" -ForegroundColor Gray
