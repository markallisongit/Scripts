USE master

IF EXISTS (SELECT 1 
           FROM tempdb.sys.tables 
           WHERE name = 'whoisactive_output' 
             AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP TABLE tempdb.dbo.whoisactive_output;
END;

CREATE CLUSTERED INDEX CIDX_whoisactive_output ON tempdb..whoisactive_output (start_time);

CREATE NONCLUSTERED INDEX IX_whoisactive_output_collectiontime ON tempdb..whoisactive_output (collection_time);
GO

DECLARE @s VARCHAR(MAX)
EXEC sp_WhoIsActive
    @get_plans = 1,
	@get_outer_command=1,
	@format_output = 0,
    @return_schema = 1,
    @schema = @s OUTPUT

SET @s = REPLACE(@s, '<table_name>', 'tempdb.dbo.whoisactive_output')

EXEC(@s)


-- run this in a SQL Agent job
EXEC sp_WhoIsActive
    @get_plans = 1,
	@get_outer_command=1,
	@format_output = 0,
    @destination_table = 'tempdb.dbo.whoisactive_output'

