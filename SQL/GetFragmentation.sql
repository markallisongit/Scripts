SELECT TOP 10 
	OBJECT_NAME([object_id]) AS ObjectName,
* FROM 
sys.dm_db_index_physical_stats (DB_ID(N'distribution'), NULL, NULL, NULL , NULL)
WHERE page_count > 100000
ORDER BY avg_fragmentation_in_percent DESC;