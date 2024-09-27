USE tempdb;
GO
-- by file
SELECT DB_NAME() AS DbName, 
    name AS FileName, 
    type_desc,
    size/128.0 AS CurrentSizeMB,  
    size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB
FROM sys.database_files
WHERE type IN (0,1);

-- aggregate
SELECT 
    DB_NAME() AS DbName, 
    type_desc,
    SUM(size / 128.0) AS TotalSizeMB,  
    SUM(size / 128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) / 128.0) AS TotalFreeSpaceMB,
    SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) / 128.0) AS TotalUsedSpaceMB,
    (SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT) / 128.0) / SUM(size / 128.0)) * 100 AS UsedPercent
FROM sys.database_files
WHERE type IN (0,1)
GROUP BY type_desc;

SELECT COUNT(*) FROM sys.tables
-- killed after 4 mins