-- =====================================================================================
-- Universal PostgreSQL Schema Extraction Query for DER-Viewer
-- Produces complete structural metadata (Tables, Columns, Types, PK, FK, UK)
-- Compatible with PostgreSQL 12+
-- =====================================================================================

-- 1. All Foreign Key Relationships
SELECT 
    tc.table_schema, 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    tc.constraint_name,
    rc.delete_rule
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
    JOIN information_schema.referential_constraints AS rc
      ON rc.constraint_name = tc.constraint_name
      AND rc.constraint_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
  AND tc.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY tc.table_schema, tc.table_name, kcu.ordinal_position;

-- 2. All Columns with Types, Nullability, Defaults
SELECT 
    c.table_schema, 
    c.table_name, 
    c.column_name, 
    c.data_type, 
    c.udt_name,
    c.is_nullable, 
    c.column_default
FROM information_schema.columns c
WHERE c.table_schema NOT IN ('pg_catalog', 'information_schema')
ORDER BY c.table_schema, c.table_name, c.ordinal_position;

-- 3. Primary Key & Unique Constraints
SELECT 
    tc.table_schema, 
    tc.table_name, 
    tc.constraint_type, 
    kcu.column_name, 
    tc.constraint_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
  ON tc.constraint_name = kcu.constraint_name 
  AND tc.table_schema = kcu.table_schema
WHERE tc.table_schema NOT IN ('pg_catalog', 'information_schema')
  AND tc.constraint_type IN ('PRIMARY KEY', 'UNIQUE')
ORDER BY tc.table_schema, tc.table_name, tc.constraint_type, kcu.ordinal_position;
