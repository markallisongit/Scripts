
/* https://kendralittle.com/2017/01/24/how-to-find-queries-using-an-index-and-queries-using-index-hints/ */
/* Execution plan cache */
SELECT 
    querystats.plan_handle,
    querystats.query_hash,
    SUBSTRING(sqltext.text, (querystats.statement_start_offset / 2) + 1, 
                (CASE querystats.statement_end_offset 
                    WHEN -1 THEN DATALENGTH(sqltext.text) 
                    ELSE querystats.statement_end_offset 
                END - querystats.statement_start_offset) / 2 + 1) AS sqltext, 
    querystats.execution_count,
    querystats.total_logical_reads,
    querystats.total_logical_writes,
    querystats.creation_time,
    querystats.last_execution_time,
    CAST(query_plan AS xml) as plan_xml
FROM sys.dm_exec_query_stats as querystats
CROSS APPLY sys.dm_exec_text_query_plan
    (querystats.plan_handle, querystats.statement_start_offset, querystats.statement_end_offset) 
    as textplan
CROSS APPLY sys.dm_exec_sql_text(querystats.sql_handle) AS sqltext 
WHERE 
    textplan.query_plan like '%IX_SubOrders_BatchOrderID%'
ORDER BY querystats.last_execution_time DESC
OPTION (RECOMPILE, MAXDOP 8);
GO
-- 00:02:38
-- doesn't really work because it reports stats usage, not index usage.




-- find out if this index should have some includes
SELECT
    qsq.query_id,
    qsq.query_hash,
    (SELECT TOP 1 qsqt.query_sql_text 
     FROM sys.query_store_query_text qsqt
     WHERE qsqt.query_text_id = MAX(qsq.query_text_id)) AS sqltext,
    SUM(qrs.count_executions) AS execution_count,
    SUM(qrs.count_executions) * AVG(qrs.avg_logical_io_reads) AS est_logical_reads,
    SUM(qrs.count_executions) * AVG(qrs.avg_logical_io_writes) AS est_writes,
    MIN(qrs.last_execution_time) AS min_execution_time,
    MAX(qrs.last_execution_time) AS last_execution_time,
    SUM(qsq.count_compiles) AS sum_compiles,
    TRY_CONVERT(XML, (SELECT TOP 1 qsp2.query_plan 
                      FROM sys.query_store_plan qsp2
                      WHERE qsp2.query_id = qsq.query_id
                      ORDER BY qsp2.plan_id DESC)) AS query_plan
FROM sys.query_store_query qsq
JOIN sys.query_store_plan qsp ON qsq.query_id = qsp.query_id
CROSS APPLY (SELECT TRY_CONVERT(XML, qsp.query_plan) AS query_plan_xml) AS qpx
JOIN sys.query_store_runtime_stats qrs ON qsp.plan_id = qrs.plan_id
JOIN sys.query_store_runtime_stats_interval qsrsi ON qrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
WHERE    
    qrs.last_execution_time >= DATEADD(HOUR, -1, GETUTCDATE()) -- Filter for last 1 hours
	AND qsp.query_plan LIKE N'%IX_SubOrders_BatchOrderID%'
    --AND qsp.query_plan NOT LIKE '%query_store_runtime_stats%' /* Not a query store query */
    --AND qsp.query_plan NOT LIKE '%dm_exec_sql_text%' /* Not a query searching the plan cache */

GROUP BY 
    qsq.query_id, qsq.query_hash
OPTION (RECOMPILE, MAXDOP 8);
-- cancelled after 25 mins because it is returning statistics info, not index info and taking too long
