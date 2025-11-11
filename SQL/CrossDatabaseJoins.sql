SELECT 
    DB_NAME() AS [Current Database],
    OBJECT_SCHEMA_NAME(m.object_id) AS [Schema],
    o.name AS [Object Name],
    o.type_desc AS [Object Type],
    CASE 
        WHEN m.definition LIKE '%FROM [_].[_].[_]%' OR m.definition LIKE '%FROM [_]..[_]%' THEN 'FROM clause'
        WHEN m.definition LIKE '%JOIN [_].[_].[_]%' OR m.definition LIKE '%JOIN [_]..[_]%' THEN 'JOIN clause'
        WHEN m.definition LIKE '%INSERT INTO [_].[_].[_]%' OR m.definition LIKE '%INSERT INTO [_]..[_]%' THEN 'INSERT INTO'
        WHEN m.definition LIKE '%UPDATE [_].[_].[_]%' OR m.definition LIKE '%UPDATE [_]..[_]%' THEN 'UPDATE'
        WHEN m.definition LIKE '%DELETE FROM [_].[_].[_]%' OR m.definition LIKE '%DELETE FROM [_]..[_]%' THEN 'DELETE FROM'
        ELSE 'Other reference'
    END AS [Reference Type],
    m.definition AS [SQL Definition]
FROM sys.sql_modules m
INNER JOIN sys.objects o ON m.object_id = o.object_id
WHERE 
    (
        m.definition LIKE '%[_].[_].[_]%' -- three-part name
        OR m.definition LIKE '%[_]..[_]%' -- shorthand three-part name
    )
    AND m.definition NOT LIKE '%[sys]%'
    AND m.definition NOT LIKE '%[INFORMATION_SCHEMA]%'
    AND m.definition NOT LIKE '%[msdb]%'
    AND m.definition NOT LIKE '%[tempdb]%'
ORDER BY [Schema], [Object Name];
