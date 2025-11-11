
-- Get SQL Server start time (when usage stats were reset)
DECLARE @SQLServerStartTime DATETIME;
SELECT @SQLServerStartTime = sqlserver_start_time FROM sys.dm_os_sys_info;

-- Display index statistics information
SELECT 
    DB_NAME() AS DatabaseName,
    SCHEMA_NAME(o.schema_id) AS SchemaName,
    o.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    STATS_DATE(i.object_id, i.index_id) AS LastStatsUpdated,
    DATEDIFF(DAY, STATS_DATE(i.object_id, i.index_id), GETDATE()) AS DaysSinceLastUpdate,
    ISNULL(ius.user_scans, 0) AS UserScans,
    ISNULL(ius.user_seeks, 0) AS UserSeeks,
    ISNULL(ius.user_lookups, 0) AS UserLookups,
    ISNULL(ius.user_updates, 0) AS UserUpdates,
    -- Calculate scan percentage
    CASE WHEN (ISNULL(ius.user_scans, 0) + ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_lookups, 0)) = 0 
         THEN 0 
         ELSE CAST((ISNULL(ius.user_scans, 0) * 100.0) / 
              (ISNULL(ius.user_scans, 0) + ISNULL(ius.user_seeks, 0) + ISNULL(ius.user_lookups, 0)) AS DECIMAL(18,2))
    END AS ScanPercent,
    @SQLServerStartTime AS StatsResetTime,
    DATEDIFF(DAY, @SQLServerStartTime, GETDATE()) AS DaysSinceStatsReset,
    ius.last_user_seek AS LastSeekTime,
    ius.last_user_scan AS LastScanTime,
    ius.last_user_lookup AS LastLookupTime,
    ius.last_user_update AS LastUpdateTime
FROM 
    sys.indexes i
INNER JOIN 
    sys.objects o ON i.object_id = o.object_id
LEFT JOIN 
    sys.dm_db_index_usage_stats ius ON i.object_id = ius.object_id 
    AND i.index_id = ius.index_id
    AND ius.database_id = DB_ID()
WHERE 
    o.type_desc = 'USER_TABLE'
    AND i.type > 0 -- Exclude HEAPS (type = 0)
ORDER BY 
    SchemaName, TableName, IndexName;