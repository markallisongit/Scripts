DECLARE @TableName sysname = 'MyTable';
SELECT OBJECT_NAME(object_id) AS [ObjectName],
       [name] AS [StatisticName],
       STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats
WHERE name NOT LIKE '_WA_Sys%'
--      AND OBJECT_NAME(object_id) = @TableName
ORDER BY 3 DESC;
