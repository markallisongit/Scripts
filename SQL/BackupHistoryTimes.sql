WITH BackupDetails AS (
    SELECT 
        bs.database_name AS DatabaseName,
        CASE 
            WHEN bs.type = 'L' THEN 'Log'
            WHEN bs.type = 'I' THEN 'Differential'
        END AS BackupType,
        bs.backup_start_date AS BackupStartTime,
        bs.backup_finish_date AS BackupFinishTime,
        DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS BackupDurationSeconds,
        bs.backup_size / 1024 / 1024 AS BackupSizeMB,
        bmf.physical_device_name AS BackupFilePath,
        -- Speed in MB per second
        CASE 
            WHEN DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) > 0 THEN 
                (bs.backup_size / 1024 / 1024) / DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date)
            ELSE 
                0 
        END AS BackupSpeedMBPerSecond
    FROM 
        msdb.dbo.backupset bs
    INNER JOIN 
        msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
    WHERE 
        bs.type IN ('I', 'L')  -- 'I' for Differential, 'L' for Log
)
SELECT 
    DatabaseName,
    BackupType,
    BackupStartTime,
    BackupFinishTime,
    BackupDurationSeconds,
    BackupSizeMB,
    BackupFilePath,
    BackupSpeedMBPerSecond
FROM 
    BackupDetails
WHERE BackupDetails.DatabaseName = 'SLM'
ORDER BY 
    BackupStartTime DESC;


-- summary
WITH BackupDetails AS (
    SELECT 
        bs.database_name AS DatabaseName,
        CASE 
            WHEN bs.type = 'L' THEN 'Log'
            WHEN bs.type = 'I' THEN 'Differential'
            WHEN bs.type = 'D' THEN 'Full'
        END AS BackupType,
        CONVERT(DATE, bs.backup_start_date) AS BackupDate,
        DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS BackupDurationSeconds,
        bs.backup_size / 1024 / 1024 AS BackupSizeMB,
        CASE 
            WHEN DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) > 0 THEN 
                (bs.backup_size / 1024 / 1024) / DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date)
            ELSE 
                0 
        END AS BackupSpeedMBPerSecond
    FROM 
        msdb.dbo.backupset bs
    INNER JOIN 
        msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
)
SELECT 
    DatabaseName,
    BackupType,
    BackupDate,
    AVG(BackupSizeMB) AS AvgBackupSizeMB,
    AVG(BackupSpeedMBPerSecond) AS AvgBackupSpeedMBPerSecond
FROM 
    BackupDetails
WHERE 
    DatabaseName = 'SLM'
GROUP BY 
    DatabaseName, BackupType, BackupDate
ORDER BY 
    BackupDate DESC, BackupType;
