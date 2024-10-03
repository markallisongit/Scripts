-- Retrieve Data Space Used, Index Space Used, Unallocated Space, Unused Space, and Total Space Used for the Current Database

SELECT 
    DB_NAME() AS DatabaseName,
    
    -- Data Space Used: Heap (0) + Clustered Indexes (1)
    CAST(SUM(CASE WHEN i.index_id IN (0, 1) THEN p.reserved_page_count ELSE 0 END) * 8.0 / 1024 / 1024 AS DECIMAL(18,2)) AS DataSpaceGB,
    
    -- Index Space Used: Non-Clustered Indexes (index_id > 1)
    CAST(SUM(CASE WHEN i.index_id > 1 THEN p.reserved_page_count ELSE 0 END) * 8.0 / 1024 / 1024 AS DECIMAL(18,2)) AS IndexSpaceGB,
    
    -- Unallocated Space: Total allocated space - (Data Space + Index Space)
    CAST(
        (
            SELECT SUM(size) * 8.0 / 1024 / 1024 
            FROM sys.database_files 
            WHERE type_desc = 'ROWS'
        ) - 
        (
            SUM(CASE WHEN i.index_id IN (0, 1) THEN p.reserved_page_count ELSE 0 END) +
            SUM(CASE WHEN i.index_id > 1 THEN p.reserved_page_count ELSE 0 END)
        ) 
        * 8.0 / 1024 / 1024 
        AS DECIMAL(18,2)
    ) AS UnallocatedSpaceGB,
    
    -- Unused Space: Internal fragmentation and free space within allocated files
    CAST(
        (
            SELECT SUM(FILEPROPERTY(name, 'SpaceUsed')) * 8.0 / 1024 / 1024 
            FROM sys.database_files 
            WHERE type_desc = 'ROWS'
        ) -
        (
            SUM(CASE WHEN i.index_id IN (0, 1) THEN p.reserved_page_count ELSE 0 END) +
            SUM(CASE WHEN i.index_id > 1 THEN p.reserved_page_count ELSE 0 END)
        ) 
        * 8.0 / 1024 / 1024 
        AS DECIMAL(18,2)
    ) AS UnusedSpaceGB,

    -- Total Space Used: Data Space + Index Space
    CAST(
        SUM(CASE WHEN i.index_id IN (0, 1) THEN p.reserved_page_count ELSE 0 END) +
        SUM(CASE WHEN i.index_id > 1 THEN p.reserved_page_count ELSE 0 END)
        AS DECIMAL(18,2)
    ) * 8.0 / 1024 / 1024 AS TotalSpaceUsedGB

FROM 
    sys.dm_db_partition_stats AS p
INNER JOIN 
    sys.indexes AS i 
    ON p.object_id = i.object_id 
    AND p.index_id = i.index_id
-- Optionally, exclude system tables
-- WHERE i.object_id > 100 -- Exclude system objects
;
