-- finds unused indexes and generates drop and create scripts
SELECT 
    o.name AS ObjectName,
    i.name AS IndexName,
    user_seeks,
    user_scans,
    user_lookups,
    user_updates,
    last_user_seek,
    last_user_scan,
    last_user_lookup,
    'IF EXISTS (SELECT * FROM sys.indexes AS idx JOIN sys.objects AS obj ON idx.object_id = obj.object_id WHERE obj.name = ''' + o.name + ''' AND idx.name = ''' + i.name + ''') ' +
    'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) AS DropIndexCommand,
    'IF NOT EXISTS (SELECT * FROM sys.indexes AS idx JOIN sys.objects AS obj ON idx.object_id = obj.object_id WHERE obj.name = ''' + o.name + ''' AND idx.name = ''' + i.name + ''') ' +
	'CREATE NONCLUSTERED INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + '.' + QUOTENAME(o.name) + 
    ' (' + STUFF((SELECT ', ' + c.name 
        FROM sys.index_columns ic 
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 0
        ORDER BY ic.key_ordinal
        FOR XML PATH('')), 1, 2, '') + ')' +
    CASE 
        WHEN EXISTS (SELECT 1 FROM sys.index_columns ic WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1)
        THEN ' INCLUDE (' + STUFF((SELECT ', ' + c.name 
            FROM sys.index_columns ic 
            JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.is_included_column = 1
            FOR XML PATH('')), 1, 2, '') + ')'
        ELSE ''
    END +
    ' WITH (ONLINE = ON);' AS RecreateIndexCommand
FROM 
    sys.dm_db_index_usage_stats AS s
JOIN 
    sys.indexes AS i ON s.object_id = i.object_id AND s.index_id = i.index_id
JOIN 
    sys.objects AS o ON i.object_id = o.object_id
WHERE 
    s.database_id = DB_ID()  -- Filters by current database
    AND i.is_primary_key = 0  -- Exclude primary key indexes
    AND i.type_desc <> 'HEAP'
    AND i.type_desc <> 'CLUSTERED'  -- Exclude clustered indexes
	AND s.last_user_seek IS NULL
	AND s.last_user_scan IS NULL
	AND s.last_user_lookup IS NULL
ORDER BY 
    ObjectName,
    IndexName;




