-- Shows index usage stats, including indexes that have never been used, and the data compression level
SELECT 
    [o].[name] AS ObjectName,
    [i].[name] AS IndexName,
    [i].[type_desc],
    
    -- Concatenates key columns with proper quoting and ordering
    STUFF(
        (
            SELECT 
                ', ' + QUOTENAME([c].[name]) + 
                CASE 
                    WHEN [ic].[is_descending_key] = 1 THEN ' DESC' 
                    ELSE '' 
                END
            FROM [sys].[index_columns] AS [ic]
            INNER JOIN [sys].[columns] AS [c] 
                ON [ic].[object_id] = [c].[object_id] 
                AND [ic].[column_id] = [c].[column_id]
            WHERE 
                [ic].[object_id] = [i].[object_id] 
                AND [ic].[index_id] = [i].[index_id] 
                AND [ic].[is_included_column] = 0
            ORDER BY [ic].[key_ordinal]
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)')
        , 1, 2, ''
    ) AS KeyColumns,
    
    -- Concatenates included columns with proper quoting and ordering
    STUFF(
        (
            SELECT 
                ', ' + QUOTENAME([c].[name])
            FROM [sys].[index_columns] AS [ic]
            INNER JOIN [sys].[columns] AS [c] 
                ON [ic].[object_id] = [c].[object_id] 
                AND [ic].[column_id] = [c].[column_id]
            WHERE 
                [ic].[object_id] = [i].[object_id] 
                AND [ic].[index_id] = [i].[index_id] 
                AND [ic].[is_included_column] = 1
            ORDER BY [ic].[index_column_id]
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)')
        , 1, 2, ''
    ) AS IncludedColumns,
    
    [s].[user_seeks],
    [s].[user_scans],
    [s].[user_lookups],
    [s].[user_updates],
    [s].[last_user_seek],
    [s].[last_user_scan],
    [s].[last_user_lookup],
    CONVERT(DECIMAL(10,2), [ps].[IndexSizeMB]) AS IndexSizeMB,
    [p].[data_compression_desc] AS DataCompression, -- New column for data compression level
    
    -- Dynamic SQL command to drop the index if it exists
    'IF EXISTS (
        SELECT * 
        FROM [sys].[indexes] AS [idx] 
        JOIN [sys].[objects] AS [obj] 
            ON [idx].[object_id] = [obj].[object_id] 
        WHERE [obj].[name] = ''' + [o].[name] + ''' 
            AND [idx].[name] = ''' + [i].[name] + '''
    ) 
    DROP INDEX ' + QUOTENAME([i].[name]) + ' ON ' + QUOTENAME(SCHEMA_NAME([o].[schema_id])) + '.' + QUOTENAME([o].[name]) + ';' AS DropIndexCommand,
    
    -- Dynamic SQL command to create the index if it does not exist
    'IF NOT EXISTS (
        SELECT * 
        FROM [sys].[indexes] AS [idx] 
        JOIN [sys].[objects] AS [obj] 
            ON [idx].[object_id] = [obj].[object_id] 
        WHERE [obj].[name] = ''' + [o].[name] + ''' 
            AND [idx].[name] = ''' + [i].[name] + '''
    ) 
    CREATE NONCLUSTERED INDEX ' + QUOTENAME([i].[name]) + ' ON ' + QUOTENAME(SCHEMA_NAME([o].[schema_id])) + '.' + QUOTENAME([o].[name]) + 
    ' (' + STUFF(
        (
            SELECT ', ' + QUOTENAME([c].[name])
            FROM [sys].[index_columns] AS [ic]
            JOIN [sys].[columns] AS [c] 
                ON [c].[object_id] = [ic].[object_id] 
                AND [c].[column_id] = [ic].[column_id]
            WHERE 
                [ic].[object_id] = [i].[object_id] 
                AND [ic].[index_id] = [i].[index_id] 
                AND [ic].[is_included_column] = 0
            ORDER BY [ic].[key_ordinal]
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)')
    , 1, 2, '') + ')' +
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM [sys].[index_columns] AS [ic] 
            WHERE 
                [ic].[object_id] = [i].[object_id] 
                AND [ic].[index_id] = [i].[index_id] 
                AND [ic].[is_included_column] = 1
        )
        THEN ' INCLUDE (' + STUFF(
            (
                SELECT ', ' + QUOTENAME([c].[name])
                FROM [sys].[index_columns] AS [ic]
                JOIN [sys].[columns] AS [c] 
                    ON [c].[object_id] = [ic].[object_id] 
                    AND [c].[column_id] = [ic].[column_id]
                WHERE 
                    [ic].[object_id] = [i].[object_id] 
                    AND [ic].[index_id] = [i].[index_id] 
                    AND [ic].[is_included_column] = 1
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)')
        , 1, 2, '') + ')'
        ELSE ''
    END +
    ' WITH (ONLINE = ON);' AS RecreateIndexCommand
    
FROM 
    [sys].[indexes] AS [i]
LEFT JOIN 
    [sys].[dm_db_index_usage_stats] AS [s] 
    ON [i].[object_id] = [s].[object_id] 
    AND [i].[index_id] = [s].[index_id] 
    AND [s].[database_id] = DB_ID()
JOIN 
    [sys].[objects] AS [o] 
    ON [i].[object_id] = [o].[object_id]
OUTER APPLY 
(
    SELECT CONVERT(DECIMAL(10,2), SUM([ps].[used_page_count]) * 8.0 / 1024) AS [IndexSizeMB]
    FROM [sys].[dm_db_partition_stats] AS [ps]
    WHERE 
        [ps].[object_id] = [i].[object_id] 
        AND [ps].[index_id] = [i].[index_id]
) AS [ps]
JOIN 
    [sys].[partitions] AS [p] 
    ON [p].[object_id] = [i].[object_id] 
    AND [p].[index_id] = [i].[index_id] -- Joining to get data compression info
WHERE 
    [s].[database_id] = DB_ID()  -- Filters by current database
    AND [i].[is_primary_key] = 0  -- Exclude primary key indexes
    AND [i].[type_desc] <> 'HEAP'
    AND [i].[type_desc] <> 'CLUSTERED'  -- Exclude clustered indexes
    AND [s].[last_user_seek] IS NULL
    AND [s].[last_user_scan] IS NULL
    AND [s].[last_user_lookup] IS NULL
ORDER BY
    [s].[user_updates] DESC;
