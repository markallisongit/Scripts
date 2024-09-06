WITH BackupHistory AS (
    SELECT
        bs.database_name,
        bs.backup_finish_date,
        bs.backup_start_date,
        bs.type,
        DATEDIFF(MINUTE, bs.backup_start_date, bs.backup_finish_date) AS backup_duration_minutes,
        CAST(bs.backup_size / 1024.0 / 1024.0 / 1024.0 AS DECIMAL(10, 2)) AS backup_size_gb,
        ROW_NUMBER() OVER (PARTITION BY bs.database_name, bs.type ORDER BY bs.backup_finish_date DESC) AS rn
    FROM
        msdb.dbo.backupset bs
    WHERE
        bs.type IN ('D', 'I', 'L')
)
SELECT
    bh.database_name,
    MAX(CASE WHEN bh.type = 'D' AND bh.rn = 1 THEN bh.backup_finish_date END) AS LastFullBackup,
    MAX(CASE WHEN bh.type = 'D' AND bh.rn = 1 THEN bh.backup_duration_minutes END) AS FullBackupDurationMinutes,
    MAX(CASE WHEN bh.type = 'D' AND bh.rn = 1 THEN bh.backup_size_gb END) AS FullBackupSizeGB,
    MAX(CASE WHEN bh.type = 'D' AND bh.rn = 1 THEN bh.backup_size_gb / NULLIF(bh.backup_duration_minutes, 0) END) AS FullBackupSpeedGBPerMinute,
    MAX(CASE WHEN bh.type = 'I' AND bh.rn = 1 THEN bh.backup_finish_date END) AS LastDiffBackup,
    MAX(CASE WHEN bh.type = 'I' AND bh.rn = 1 THEN bh.backup_duration_minutes END) AS DiffBackupDurationMinutes,
    MAX(CASE WHEN bh.type = 'I' AND bh.rn = 1 THEN bh.backup_size_gb END) AS DiffBackupSizeGB,
    MAX(CASE WHEN bh.type = 'I' AND bh.rn = 1 THEN bh.backup_size_gb / NULLIF(bh.backup_duration_minutes, 0) END) AS DiffBackupSpeedGBPerMinute,
    MAX(CASE WHEN bh.type = 'L' AND bh.rn = 1 THEN bh.backup_finish_date END) AS LastLogBackup,
    MAX(CASE WHEN bh.type = 'L' AND bh.rn = 1 THEN bh.backup_duration_minutes END) AS LogBackupDurationMinutes,
    MAX(CASE WHEN bh.type = 'L' AND bh.rn = 1 THEN bh.backup_size_gb END) AS LogBackupSizeGB,
    MAX(CASE WHEN bh.type = 'L' AND bh.rn = 1 THEN bh.backup_size_gb / NULLIF(bh.backup_duration_minutes, 0) END) AS LogBackupSpeedGBPerMinute
FROM
    BackupHistory bh
GROUP BY
    bh.database_name
ORDER BY
    bh.database_name;
