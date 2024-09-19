;WITH agg AS
(
    SELECT 
        SUM(qp.[row_count]) AS [RowsProcessed],
        SUM(qp.[estimate_row_count]) AS [TotalRows],
        MAX(qp.last_active_time) - MIN(qp.first_active_time) AS [ElapsedMS],
        MAX(IIF(qp.[close_time] = 0 AND qp.[first_row_time] > 0,
                [physical_operator_name],
                N'<Transition>')) AS [CurrentStep],
        r.session_id,
        DB_NAME(r.database_id) AS [DatabaseName],
        st.text AS [SQLCommand]
    FROM sys.dm_exec_query_profiles qp
    JOIN sys.dm_exec_requests r ON qp.session_id = r.session_id
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
    WHERE qp.[physical_operator_name] IN (N'Table Scan', N'Clustered Index Scan',
                                          N'Index Scan',  N'Sort')
    AND r.command IN ('CREATE INDEX', 'ALTER INDEX', 'ALTER TABLE')
    GROUP BY r.session_id, r.database_id, st.text
), comp AS
(
    SELECT *,
        ([TotalRows] - [RowsProcessed]) AS [RowsLeft],
        ([ElapsedMS] / 1000.0) AS [ElapsedSeconds]
    FROM agg
)
SELECT 
    [CurrentStep],
    [TotalRows],
    [RowsProcessed],
    [RowsLeft],
    CONVERT(DECIMAL(5, 2),
            (([RowsProcessed] * 1.0) / [TotalRows]) * 100) AS [PercentComplete],
    [ElapsedSeconds],
    (([ElapsedSeconds] / [RowsProcessed]) * [RowsLeft]) AS [EstimatedSecondsLeft],
	[ElapsedSeconds] / 60.0 AS [ElapsedMinutes], 
	(([ElapsedSeconds] / [RowsProcessed]) * [RowsLeft])/60.0 AS [EstimatedMinutesLeft],
    DATEADD(SECOND,
            (([ElapsedSeconds] / [RowsProcessed]) * [RowsLeft]),
            GETDATE()) AS [EstimatedCompletionTime],

    [SQLCommand],
    [DatabaseName],
CASE 
    WHEN CHARINDEX('ON ', [SQLCommand]) > 0 
         AND CHARINDEX('(', [SQLCommand]) > CHARINDEX('ON ', [SQLCommand])
    THEN SUBSTRING([SQLCommand], 
                   CHARINDEX('ON ', [SQLCommand]) + 3, 
                   CHARINDEX('(', [SQLCommand]) - CHARINDEX('ON ', [SQLCommand]) - 3)
    ELSE N'Unknown Table'
END AS [TableName]
FROM comp;
GO
