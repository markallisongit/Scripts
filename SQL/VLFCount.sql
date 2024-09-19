-- original source: https://www.sqlservercentral.com/forums/topic/db-restore-is-very-slow
SELECT [name], s.database_id,
COUNT(l.database_id) AS 'VLF Count',
SUM(vlf_size_mb) AS 'VLF Size (MB)',
SUM(CAST(vlf_active AS INT)) AS 'Active VLF',
SUM(vlf_active*vlf_size_mb) AS 'Active VLF Size (MB)',
COUNT(l.database_id)-SUM(CAST(vlf_active AS INT)) AS 'In-active VLF',
SUM(vlf_size_mb)-SUM(vlf_active*vlf_size_mb) AS 'In-active VLF Size (MB)'
FROM sys.databases s
CROSS APPLY sys.dm_db_log_info(s.database_id) l
GROUP BY [name], s.database_id
ORDER BY 'VLF Count' DESC
GO