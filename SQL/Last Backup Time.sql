;with backup_cte as
(
    select
        database_name,
        backup_type =
            case type
                when 'D' then 'database'
                when 'L' then 'log'
                when 'I' then 'differential'
                else 'other'
            end,
        backup_finish_date,
        rownum = 
            row_number() over
            (
                partition by database_name, type 
                order by backup_finish_date desc
            )
    from msdb.dbo.backupset
)
select
    database_name,
    backup_type,
    backup_finish_date
from backup_cte
where rownum = 1
order by backup_cte.backup_finish_date;