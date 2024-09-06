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
, indexes as (
	select
		p.query_id
		, p.plan_id
		, SchemaName = a.value(N'(@Schema)[1]', N'nvarchar(130)')
		, TableName = a.value(N'(@Table)[1]', N'nvarchar(130)')
		, IndexName = a.value(N'(@Index)[1]', N'nvarchar(130)')
	from plans p
	cross apply p.query_plan.nodes(N'//Object') obj (a)
)
select distinct query_id, plan_id, SchemaName, TableName, IndexName
from indexes