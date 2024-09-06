/**********************************************************************
     Instance-level
Only run on warm Server that has been running for at least 3 hours
 
http://sqlserverperformance.idera.com/memory/optimize-ad-hoc-workloads-option-sql-server-2008/
***********************************************************************/
SET NOCOUNT ON
 
SELECT objtype AS [Cache Store Type],
        COUNT_BIG(*) AS [Total Num Of Plans],
        SUM(CAST(size_in_bytes as decimal(14,2))) / 1048576 AS [Total Size In MB],
        AVG(usecounts) AS [All Plans - Ave Use Count],
        SUM(CAST((CASE WHEN usecounts = 1 THEN size_in_bytes ELSE 0 END) as decimal(14,2)))/ 1048576 AS [Size in MB of plans with a Use count = 1],
        SUM(CASE WHEN usecounts = 1 THEN 1 ELSE 0 END) AS [Number of of plans with a Use count = 1]
        FROM sys.dm_exec_cached_plans
        GROUP BY objtype
        ORDER BY [Size in MB of plans with a Use count = 1] DESC
 
DECLARE @AdHocSizeInMB decimal (14,2), @TotalSizeInMB decimal (14,2)
 
SELECT @AdHocSizeInMB = SUM(CAST((CASE WHEN usecounts = 1 AND LOWER(objtype) = 'adhoc' THEN size_in_bytes ELSE 0 END) as decimal(14,2))) / 1048576,
        @TotalSizeInMB = SUM (CAST (size_in_bytes as decimal (14,2))) / 1048576
        FROM sys.dm_exec_cached_plans 
 
SELECT @AdHocSizeInMB as [Current memory occupied by adhoc plans only used once (MB)],
         @TotalSizeInMB as [Total cache plan size (MB)],
         CAST((@AdHocSizeInMB / @TotalSizeInMB) * 100 as decimal(14,2)) as [% of total cache plan occupied by adhoc plans only used once]
IF   ((@AdHocSizeInMB / @TotalSizeInMB) * 100) > 25  -- 200MB or > 25%
        SELECT 'Switch on Optimize for ad hoc workloads as it will make a significant difference' as [Recommendation]
ELSE
        SELECT 'Setting Optimize for ad hoc workloads will make little difference' as [Recommendation]
GO
