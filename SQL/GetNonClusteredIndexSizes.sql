-- get summary
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
	i.type_desc,
    CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(18,2)) AS TotalSpaceUsed_MB,
    p.data_compression_desc AS CompressionType
FROM sys.schemas s
INNER JOIN sys.tables t ON s.schema_id = t.schema_id
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.dm_db_partition_stats ps ON p.object_id = ps.object_id 
    AND p.index_id = ps.index_id 
    AND p.partition_number = ps.partition_number
WHERE i.type_desc = 'NONCLUSTERED'
GROUP BY s.name, t.name, i.type_desc, p.data_compression_desc
HAVING CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(18,2)) > 100
ORDER BY TotalSpaceUsed_MB DESC;




-- get index details
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    'NONCLUSTERED INDEX' AS IndexType,
    CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(18,2)) AS TotalSpaceUsed_MB,
    p.data_compression_desc AS CompressionType
FROM sys.schemas s
INNER JOIN sys.tables t ON s.schema_id = t.schema_id
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.dm_db_partition_stats ps ON p.object_id = ps.object_id 
    AND p.index_id = ps.index_id 
    AND p.partition_number = ps.partition_number
WHERE i.type_desc = 'NONCLUSTERED'
GROUP BY s.name, t.name, i.name, p.data_compression_desc
HAVING CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(18,2)) > 100
ORDER BY TotalSpaceUsed_MB DESC;





-- now with create index statement to compress NIDX
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    i.name AS IndexName,
    'NONCLUSTERED INDEX' AS IndexType,
    CAST(SUM(ps.used_page_count) * 8 / 1024.0 AS DECIMAL(18,2)) AS TotalSpaceUsed_MB,
    MAX(p.data_compression_desc) AS CompressionType,
    'CREATE NONCLUSTERED INDEX ' + QUOTENAME(i.name) COLLATE DATABASE_DEFAULT + 
    ' ON ' + QUOTENAME(s.name) COLLATE DATABASE_DEFAULT + '.' + QUOTENAME(t.name) COLLATE DATABASE_DEFAULT + 
    ' (' + 
        STUFF((
            SELECT ', ' + QUOTENAME(c.name) COLLATE DATABASE_DEFAULT + 
                   CASE WHEN ic.is_descending_key = 1 THEN ' DESC' ELSE ' ASC' END
            FROM sys.index_columns ic
            JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE ic.object_id = i.object_id 
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 0
              AND ic.key_ordinal > 0
            ORDER BY ic.key_ordinal
            FOR XML PATH('')
        ), 1, 2, '') + 
    ')' +
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM sys.index_columns ic
            WHERE ic.object_id = i.object_id 
              AND ic.index_id = i.index_id
              AND ic.is_included_column = 1
        )
        THEN ' INCLUDE (' + 
            STUFF((
                SELECT ', ' + QUOTENAME(c.name) COLLATE DATABASE_DEFAULT
                FROM sys.index_columns ic
                JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                WHERE ic.object_id = i.object_id 
                  AND ic.index_id = i.index_id
                  AND ic.is_included_column = 1
                ORDER BY c.name
                FOR XML PATH('')
            ), 1, 2, '') +
            ')'
        ELSE ''
    END +
    CASE 
        WHEN i.has_filter = 1 
        THEN ' WHERE ' + i.filter_definition COLLATE DATABASE_DEFAULT
        ELSE ''
    END +
    ' WITH (DATA_COMPRESSION = PAGE, ONLINE = ON, SORT_IN_TEMPDB = ON)'
    AS CreateIndexStatement
FROM sys.schemas s
INNER JOIN sys.tables t ON s.schema_id = t.schema_id
INNER JOIN sys.indexes i ON t.object_id = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
INNER JOIN sys.dm_db_partition_stats ps ON p.object_id = ps.object_id 
    AND p.index_id = ps.index_id 
    AND p.partition_number = ps.partition_number
WHERE i.type_desc = 'NONCLUSTERED'
GROUP BY 
    s.name, t.name, i.name, i.object_id, i.index_id, i.has_filter, i.filter_definition
ORDER BY s.name, t.name, i.name;