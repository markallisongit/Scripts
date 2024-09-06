SELECT status,
       COUNT(*) AS [Count]
FROM sys.dm_os_schedulers
GROUP BY status;

SELECT cpu_count
FROM sys.dm_os_sys_info;
