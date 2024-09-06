WITH XMLNAMESPACES(DEFAULT '
http://schemas.microsoft.com/sqlserver/2004/07/showplan')
, plans as (
	select
		qp.query_id
		, qp.plan_id
		, query_plan = try_cast(qp.query_plan as xml)
	from sys.query_store_plan qp
	where qp.plan_id = 395
)
, stats as (
	select
		p.query_id
		, p.plan_id
		, SchemaName = a.value(N'(@Schema)[1]', N'nvarchar(130)')
		, TableName = a.value(N'(@Table)[1]', N'nvarchar(130)')
		, StatsName = a.value(N'(@Statistics)[1]', N'nvarchar(130)')
	from plans p
	cross apply p.query_plan.nodes(N'/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/OptimizerStatsUsage/StatisticsInfo') obj (a)
)
select query_id, plan_id, SchemaName, TableName, StatsName
from stats