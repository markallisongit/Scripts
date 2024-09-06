USE msdb;
GO

WITH JobSchedules AS (
    SELECT 
        js.job_id,
        s.name AS schedule_name,
        js.next_run_date,
        js.next_run_time,
        s.enabled AS schedule_enabled
    FROM 
        dbo.sysjobschedules js
    INNER JOIN 
        dbo.sysschedules s ON js.schedule_id = s.schedule_id
),
LastRunInfo AS (
    SELECT 
        j.job_id,
        j.name AS job_name,
        CASE 
            WHEN j.enabled = 1 THEN 'Enabled'
            ELSE 'Disabled'
        END AS job_status,
        h.run_status,
        h.run_date,
        h.run_time,
        h.run_duration,
        CASE 
            WHEN h.run_date IS NOT NULL AND ISDATE(SUBSTRING(CAST(h.run_date AS VARCHAR(8)), 1, 4) + '-' +
                                                    SUBSTRING(CAST(h.run_date AS VARCHAR(8)), 5, 2) + '-' +
                                                    SUBSTRING(CAST(h.run_date AS VARCHAR(8)), 7, 2)) = 1 THEN
                CONVERT(DATETIME, SUBSTRING(CAST(h.run_date AS VARCHAR(8)), 1, 4) + '-' +
                                 SUBSTRING(CAST(h.run_date AS VARCHAR(8)), 5, 2) + '-' +
                                 SUBSTRING(CAST(h.run_date AS VARCHAR(8)), 7, 2) + ' ' +
                                 STUFF(STUFF(RIGHT('000000' + CAST(h.run_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':'))
            ELSE
                NULL
        END AS last_run_datetime
    FROM 
        dbo.sysjobs j
    LEFT JOIN 
        (SELECT 
            job_id,
            run_status,
            run_date,
            run_time,
            run_duration,
            ROW_NUMBER() OVER (PARTITION BY job_id ORDER BY run_date DESC, run_time DESC) AS rn
        FROM 
            dbo.sysjobhistory
        WHERE 
            step_id = 0) AS h ON j.job_id = h.job_id AND h.rn = 1
)
SELECT 
    lri.job_name,
    lri.job_status,
    lri.last_run_datetime,
    COALESCE((lri.run_duration / 10000 * 60) + ((lri.run_duration % 10000) / 100), 0) AS last_run_duration_minutes,
    CASE 
        WHEN js.next_run_date IS NOT NULL AND ISDATE(SUBSTRING(CAST(js.next_run_date AS VARCHAR(8)), 1, 4) + '-' +
                                                     SUBSTRING(CAST(js.next_run_date AS VARCHAR(8)), 5, 2) + '-' +
                                                     SUBSTRING(CAST(js.next_run_date AS VARCHAR(8)), 7, 2)) = 1 THEN
            CONVERT(DATETIME, SUBSTRING(CAST(js.next_run_date AS VARCHAR(8)), 1, 4) + '-' +
                             SUBSTRING(CAST(js.next_run_date AS VARCHAR(8)), 5, 2) + '-' +
                             SUBSTRING(CAST(js.next_run_date AS VARCHAR(8)), 7, 2) + ' ' +
                             STUFF(STUFF(RIGHT('000000' + CAST(js.next_run_time AS VARCHAR(6)), 6), 3, 0, ':'), 6, 0, ':'))
        ELSE
            NULL
    END AS next_run_datetime,
    js.schedule_name,
    CASE 
        WHEN js.schedule_enabled = 1 THEN 'Enabled'
        ELSE 'Disabled'
    END AS schedule_status
FROM 
    LastRunInfo lri
LEFT JOIN 
    JobSchedules js ON lri.job_id = js.job_id
WHERE 
    lri.job_status = 'Enabled'
ORDER BY 
    5;
GO
