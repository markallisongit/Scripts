-- finds unused tables that have never been read since last service restart
SELECT DISTINCT ObjectName AS TableName FROM
(
SELECT 
    o.name AS ObjectName,
    i.name AS IndexName,
    user_seeks,
    user_scans,
    user_lookups,
    user_updates,
    last_user_seek,
    last_user_scan,
    last_user_lookup
FROM 
    sys.dm_db_index_usage_stats AS s
JOIN 
    sys.indexes AS i ON s.object_id = i.object_id AND s.index_id = i.index_id
JOIN 
    sys.objects AS o ON i.object_id = o.object_id
WHERE 
    s.database_id = DB_ID()
	AND s.user_seeks= 0
	AND s.user_scans = 0
	AND s.user_lookups = 0
) unusedIndexes;