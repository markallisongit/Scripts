-- Create a temporary table to store the results
IF OBJECT_ID('tempdb..#dbSizes') IS NOT NULL DROP TABLE #dbSizes;
CREATE TABLE #dbSizes (
    DatabaseName SYSNAME,
    DataSize_MB DECIMAL(18, 2),
    DataSpaceUsed_MB DECIMAL(18, 2),
    LogSize_MB DECIMAL(18, 2),
    LogSpaceUsed_MB DECIMAL(18, 2)
);

-- Declare variables for iteration
DECLARE @dbName SYSNAME;
DECLARE @sql NVARCHAR(MAX);

-- Cursor to iterate over each database
DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM sys.databases 
WHERE state_desc = 'ONLINE'; -- Only include online databases

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @dbName;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Build dynamic SQL to gather data for each database
    SET @sql = N'
    USE ' + QUOTENAME(@dbName) + ';
    INSERT INTO #dbSizes (DatabaseName, DataSize_MB, DataSpaceUsed_MB, LogSize_MB, LogSpaceUsed_MB)
    SELECT
        DB_NAME() AS DatabaseName,
        SUM(CASE WHEN type_desc = ''ROWS'' THEN size * 8.0 / 1024 ELSE 0 END) AS DataSize_MB,
        (SELECT SUM(reserved_page_count) * 8.0 / 1024 FROM sys.dm_db_partition_stats) AS DataSpaceUsed_MB,
        SUM(CASE WHEN type_desc = ''LOG'' THEN size * 8.0 / 1024 ELSE 0 END) AS LogSize_MB,
        (SELECT SUM(CAST(FILEPROPERTY(name, ''SpaceUsed'') AS DECIMAL(18, 2)) * 8.0 / 1024) FROM sys.database_files WHERE type_desc = ''LOG'') AS LogSpaceUsed_MB
    FROM sys.database_files;
    ';

    -- Execute the dynamic SQL
    EXEC sp_executesql @sql;

    FETCH NEXT FROM db_cursor INTO @dbName;
END;

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Select the results
SELECT DatabaseName, DataSize_MB, DataSpaceUsed_MB, LogSize_MB, LogSpaceUsed_MB
FROM #dbSizes
ORDER BY DatabaseName;

-- Clean up
DROP TABLE #dbSizes;
