-- Create a temporary table to store results
CREATE TABLE #DBSpaceUsage (
    DatabaseName NVARCHAR(128),
    TotalSpaceAllocatedGB DECIMAL(18,2),
    TotalSpaceUsedGB DECIMAL(18,2)
)

-- Execute for each database
EXEC sp_MSforeachdb '
USE [?];
INSERT INTO #DBSpaceUsage
SELECT 
    DB_NAME() AS DatabaseName,
    CAST(SUM(CAST(size AS BIGINT)) * 8 / 1024.0 / 1024.0 AS DECIMAL(18,2)) AS TotalSpaceAllocatedGB,
    CAST(SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS BIGINT)) * 8 / 1024.0 / 1024.0 AS DECIMAL(18,2)) AS TotalSpaceUsedGB
FROM 
    sys.database_files
WHERE 
    type = 0  -- Only data files (type 0)
'

-- Return results
SELECT * FROM #DBSpaceUsage ORDER BY TotalSpaceAllocatedGB DESC;

-- Clean up
DROP TABLE #DBSpaceUsage;