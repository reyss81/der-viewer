#!/usr/bin/env bash
# ==============================================================================
# Automated PostgreSQL to Mermaid ERD Extractor for DER-Viewer (Bash version)
# ==============================================================================
set -euo pipefail

DB_HOST="${1:-localhost}"
DB_PORT="${2:-5432}"
DB_USER="${3:-postgres}"
DB_NAME="${4:-postgres}"
OUTPUT_FILE="${5:-diagram.mmd}"
SCHEMAS="${6:-}"

echo "🔍 Extrayendo metadatos de PostgreSQL [$DB_NAME @ $DB_HOST:$DB_PORT]..."

SCHEMA_FILTER="AND table_schema NOT IN ('pg_catalog', 'information_schema')"
if [ -n "$SCHEMAS" ]; then
    FORMATTED_SCHEMAS=$(echo "$SCHEMAS" | sed "s/,/','/g")
    SCHEMA_FILTER="AND table_schema IN ('$FORMATTED_SCHEMAS')"
fi

export PGPASSWORD="${PGPASSWORD:-}"

python3 - <<EOF
import subprocess
import sys

def run_psql(query):
    cmd = [
        "psql", "-h", "$DB_HOST", "-p", "$DB_PORT", "-U", "$DB_USER",
        "-d", "$DB_NAME", "-A", "-F", "|", "-t", "-c", query
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=True)
    return res.stdout.strip().split('\n')

# 1. Fetch Constraints
sql_cons = """
SELECT tc.table_schema || '.' || tc.table_name, tc.constraint_type, kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
WHERE tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE') $SCHEMA_FILTER;
"""
pk_map = set()
uk_map = set()
for line in run_psql(sql_cons):
    if not line: continue
    parts = line.split('|')
    if len(parts) >= 3:
        tbl, ctype, col = parts[0].strip(), parts[1].strip(), parts[2].strip()
        if ctype == 'PRIMARY KEY': pk_map.add(f"{tbl}.{col}")
        elif ctype == 'UNIQUE': uk_map.add(f"{tbl}.{col}")

# 2. Fetch FKs
sql_fks = """
SELECT tc.table_schema || '.' || tc.table_name, kcu.column_name,
       ccu.table_schema || '.' || ccu.table_name, ccu.column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
  ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' $SCHEMA_FILTER;
"""
fk_map = set()
relationships = []
seen_rel = set()
for line in run_psql(sql_fks):
    if not line: continue
    parts = line.split('|')
    if len(parts) >= 4:
        src_tbl, src_col, tgt_tbl, tgt_col = [p.strip() for p in parts[:4]]
        fk_map.add(f"{src_tbl}.{src_col}")
        src_alias = src_tbl.replace('.', '_')
        tgt_alias = tgt_tbl.replace('.', '_')
        rel_key = f"{tgt_alias}->{src_alias}:{src_col}"
        if rel_key not in seen_rel:
            seen_rel.add(rel_key)
            relationships.append(f'    {tgt_alias} ||--o{{ {src_alias} : "{src_col}"')

# 3. Fetch Columns
sql_cols = """
SELECT table_schema || '.' || table_name, column_name, data_type, udt_name
FROM information_schema.columns
WHERE 1=1 $SCHEMA_FILTER
ORDER BY table_schema, table_name, ordinal_position;
"""
tables = {}
for line in run_psql(sql_cols):
    if not line: continue
    parts = line.split('|')
    if len(parts) >= 4:
        tbl, col, dtype, udt = [p.strip() for p in parts[:4]]
        clean_type = "varchar" if "char" in dtype else "int" if "int" in dtype else "timestamptz" if "time" in dtype else udt
        tag = ""
        key = f"{tbl}.{col}"
        is_pk = key in pk_map
        is_fk = key in fk_map
        is_uk = key in uk_map
        if is_pk and is_fk: tag = "PK_FK"
        elif is_pk: tag = "PK"
        elif is_fk: tag = "FK"
        elif is_uk: tag = "UK"
        
        tables.setdefault(tbl, []).append((col, clean_type, tag))

with open("$OUTPUT_FILE", "w", encoding="utf-8") as f:
    f.write("erDiagram\n")
    for tbl in sorted(tables.keys()):
        alias = tbl.replace('.', '_')
        f.write(f'    {alias}["{tbl}"] {{\n')
        for col, ctype, tag in tables[tbl]:
            if tag:
                f.write(f'        {ctype} {col} {tag}\n')
            else:
                f.write(f'        {ctype} {col}\n')
        f.write('    }\n\n')
    for rel in relationships:
        f.write(f"{rel}\n")

print(f"✅ Diagrama generado con éxito en: $OUTPUT_FILE")
EOF
