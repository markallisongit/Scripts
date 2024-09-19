-- Create a temporary table to store the query text, query ID, plan ID, and object name
IF OBJECT_ID('tempdb..#ForcedPlans') IS NOT NULL
    DROP TABLE #ForcedPlans;

CREATE TABLE #ForcedPlans (
    QueryText NVARCHAR(MAX),
    QueryId BIGINT,
    PlanId BIGINT,
    ObjectName NVARCHAR(256)
);

DECLARE @query_id BIGINT, @plan_id BIGINT, @query_text NVARCHAR(MAX), @object_id INT, @object_name NVARCHAR(256);
DECLARE @debug BIT = 0;  -- Set to 1 to enable debug mode (print statements instead of execution)

-- Retrieve all forced plans directly from Query Store
WITH ForcedPlansData AS (
    SELECT 
        p.query_id, 
        p.plan_id, 
        q.object_id, 
        qt.query_sql_text AS QueryText
    FROM sys.query_store_plan p
    JOIN sys.query_store_query q ON p.query_id = q.query_id
    JOIN sys.query_store_query_text qt ON q.query_text_id = qt.query_text_id
    WHERE p.is_forced_plan = 1
)
-- Insert the data into the temporary table
INSERT INTO #ForcedPlans (QueryText, QueryId, PlanId, ObjectName)
SELECT 
    QueryText, 
    query_id, 
    plan_id, 
    OBJECT_NAME(object_id) AS ObjectName
FROM ForcedPlansData;

-- loop through the forced plans and unforce them
DECLARE forced_plans_cursor CURSOR FOR
SELECT QueryId, PlanId, ObjectName
FROM #ForcedPlans;

OPEN forced_plans_cursor;
FETCH NEXT FROM forced_plans_cursor INTO @query_id, @plan_id, @object_name;

-- Loop through all forced plans and unforce them
WHILE @@FETCH_STATUS = 0
BEGIN
    IF @debug = 1
    BEGIN
        -- Print the statement for debugging
        PRINT 'EXEC sp_query_store_unforce_plan @query_id = ' + CAST(@query_id AS NVARCHAR(20)) + ', @plan_id = ' + CAST(@plan_id AS NVARCHAR(20));
    END
    ELSE
    BEGIN
        -- Unforce the plan
        EXEC sp_query_store_unforce_plan @query_id = @query_id, @plan_id = @plan_id;
    END

    -- Fetch the next forced plan
    FETCH NEXT FROM forced_plans_cursor INTO @query_id, @plan_id, @object_name;
END

-- Close and deallocate the cursor
CLOSE forced_plans_cursor;
DEALLOCATE forced_plans_cursor;

-- Output the contents of the temporary table
SELECT QueryText, QueryId, PlanId, ObjectName
FROM #ForcedPlans;

-- Optional: Drop the temporary table after use
-- DROP TABLE #ForcedPlans;
