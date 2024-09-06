SELECT
    [AllocUnitName] AS N'Index',
    (CASE [Context]
        WHEN N'LCX_INDEX_LEAF' THEN N'Nonclustered'
        WHEN N'LCX_CLUSTERED' THEN N'Clustered'
        ELSE N'Non-Leaf'
    END) AS [SplitType],
    COUNT (1) AS [SplitCount]
FROM
    fn_dblog (NULL, NULL)
WHERE
    [Operation] = N'LOP_DELETE_SPLIT'
GROUP BY [AllocUnitName], [Context]
ORDER BY SplitCount DESC;
-- 00:01:55

-- top operations
SELECT Operation, COUNT(*) AS [count]
FROM  fn_dblog (NULL, NULL)
GROUP BY Operation
ORDER BY [count]