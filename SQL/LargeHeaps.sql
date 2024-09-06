SELECT -- TOP 1000
    a3.NAME AS SchemaName,
    a2.NAME AS TableName,
    a1.ROWS AS Row_Count,
    (a1.reserved) * 8.0 / 1024 AS reserved_mb,
    a1.DATA * 8.0 / 1024 AS data_mb,
    (CASE WHEN (a1.USED) > a1.DATA THEN (a1.USED) - a1.DATA ELSE 0 END) * 8.0 / 1024 AS index_size_mb,
    (CASE WHEN (a1.reserved) > a1.USED THEN (a1.reserved) - a1.USED ELSE 0 END) * 8.0 / 1024 AS unused_mb
FROM
    (
        SELECT
            ps.object_id,
            SUM(CASE WHEN (ps.index_id < 2) THEN row_count ELSE 0 END) AS [rows],
            SUM(ps.reserved_page_count) AS reserved,
            SUM(
                CASE 
                    WHEN (ps.index_id < 2) THEN (ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count)
                    ELSE (ps.lob_used_page_count + ps.row_overflow_used_page_count)
                END
            ) AS data,
            SUM(ps.used_page_count) AS used
        FROM
            sys.dm_db_partition_stats ps
        GROUP BY
            ps.object_id
    ) AS a1
INNER JOIN sys.all_objects a2 ON a1.OBJECT_ID = a2.OBJECT_ID
INNER JOIN sys.schemas a3 ON a2.SCHEMA_ID = a3.SCHEMA_ID
LEFT JOIN sys.indexes idx ON a2.OBJECT_ID = idx.OBJECT_ID AND idx.TYPE = 1 -- Clustered index
WHERE
    a2.TYPE <> N'S'   -- Exclude system tables
    AND a2.TYPE <> N'IT'  -- Exclude internal tables
    AND idx.OBJECT_ID IS NULL -- Only include tables without clustered index (heaps)
	AND a1.DATA * 8.0 / 1024 > 1000
ORDER BY
    a1.data DESC;
