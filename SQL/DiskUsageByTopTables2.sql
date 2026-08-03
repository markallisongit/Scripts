SELECT 
    SCHEMA_NAME(t.schema_id) AS [Schema],
    t.name AS [Table],
    SUM(ps.reserved_page_count) * 8 AS [Reserved Space (KB)],
    SUM(ps.used_page_count) * 8 AS [Data Space (KB)],
    SUM(ps.reserved_page_count - ps.used_page_count) * 8 AS [Unused Space (KB)],
    SUM(CASE 
        WHEN ps.index_id IN (0, 1) THEN ps.row_count 
        ELSE 0 
    END) AS [Row Count],
    FORMAT(SUM(ps.reserved_page_count) * 8.0 / 1024, 'N2') AS [Reserved Space (MB)],
    FORMAT(SUM(ps.used_page_count) * 8.0 / 1024, 'N2') AS [Data Space (MB)],
    FORMAT(SUM(ps.reserved_page_count - ps.used_page_count) * 8.0 / 1024, 'N2') AS [Unused Space (MB)]
FROM 
    sys.tables t
    INNER JOIN sys.dm_db_partition_stats ps ON t.object_id = ps.object_id
    /*
WHERE 
    SCHEMA_NAME(t.schema_id) = 'cdc'
*/
GROUP BY 
    t.schema_id, 
    t.name
ORDER BY 
    SUM(ps.reserved_page_count) DESC;