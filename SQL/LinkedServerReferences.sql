DROP TABLE IF EXISTS ##LinkedServerReferences;
go
CREATE TABLE ##LinkedServerReferences (
    [Database] NVARCHAR(128),
    [Schema] NVARCHAR(128),
    [Object Name] NVARCHAR(128),
    [Object Type] NVARCHAR(60),
    [Reference Type] NVARCHAR(40)
);

DECLARE @DatabaseName NVARCHAR(255);
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR FOR
SELECT name 
FROM sys.databases 
WHERE database_id > 4 -- Exclude system databases
  AND state_desc = 'ONLINE';

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = '
    INSERT INTO ##LinkedServerReferences ([Database], [Schema], [Object Name], [Object Type], [Reference Type])
    SELECT 
        DB_NAME() AS [Database],
        OBJECT_SCHEMA_NAME(m.object_id) AS [Schema],
        o.name AS [Object Name],
        o.type_desc AS [Object Type],
        CASE 
            WHEN m.definition LIKE ''%OPENQUERY%'' THEN ''OPENQUERY''
            WHEN m.definition LIKE ''%OPENDATASOURCE%'' THEN ''OPENDATASOURCE''
            WHEN m.definition LIKE ''%OPENROWSET%'' THEN ''OPENROWSET''
            WHEN m.definition LIKE ''%[_].[_].[_].[_]%'' THEN ''Four-part naming''
            WHEN m.definition LIKE ''%[_].[_]..[_]%'' THEN ''Shorthand four-part naming''
            ELSE ''Other reference''
        END AS [Reference Type]
    FROM sys.sql_modules m
    INNER JOIN sys.objects o ON m.object_id = o.object_id
    WHERE 
        m.definition LIKE ''%OPENQUERY%'' OR
        m.definition LIKE ''%OPENDATASOURCE%'' OR
        m.definition LIKE ''%OPENROWSET%'' OR
        m.definition LIKE ''%[_].[_].[_].[_]%'' OR
        m.definition LIKE ''%[_].[_]..[_]%'' 
    ';
    SET @SQL = 'USE [' + @DatabaseName + ']; ' + @SQL;
    EXEC sp_executesql @SQL;
    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- Return the combined results
SELECT * FROM ##LinkedServerReferences
ORDER BY [Database], [Schema], [Object Name];
