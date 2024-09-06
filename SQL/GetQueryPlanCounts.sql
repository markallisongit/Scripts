-- how many plans for each query hash?
SELECT [query_hash], COUNT (DISTINCT [query_plan_hash])
FROM [sys].[dm_exec_query_stats]
GROUP BY [query_hash]
ORDER BY 2 DESC;