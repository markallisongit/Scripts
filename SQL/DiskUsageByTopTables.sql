SELECT 
    s.name AS SchemaName,
    t.name AS TableName,
    SUM(ps.row_count) AS RowCounts,
    SUM(ps.reserved_page_count * 8) AS TotalSpaceKB,
    SUM(ps.used_page_count * 8) AS UsedSpaceKB,
    SUM((ps.reserved_page_count - ps.used_page_count) * 8) AS UnusedSpaceKB
FROM 
    sys.dm_db_partition_stats ps
    INNER JOIN sys.objects t ON ps.object_id = t.object_id
    INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE 
    t.type = 'U'
    AND ps.index_id IN (0, 1)
GROUP BY 
    s.name, t.name
ORDER BY 
   UsedSpaceKB DESC;