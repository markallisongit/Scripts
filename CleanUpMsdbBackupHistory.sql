USE [msdb]

-- number of days of history to keep
DECLARE @DaysToKeep INT = 6

-- number of days to delete at a time
DECLARE @chunk_days INT = 1

DECLARE @ChunkDate DATETIME
DECLARE @CleanupDate DATETIME

-- get the recovery model of msdb
DECLARE @recovery_model VARCHAR (20) 
SELECT @recovery_model = recovery_model_desc FROM sys.databases where name = 'msdb'

-- set the cleanup date
SET @CleanupDate = DATEADD(dd, @DaysToKeep * -1, GETDATE())
PRINT 'Keeping history up to: ' + CAST(@CleanupDate AS varchar(30))

-- get the oldest date in the history
DECLARE @min_date DATETIME
SELECT @min_date = min(backup_finish_date)
from msdb.dbo.backupset

PRINT 'Oldest date in history: ' + CAST(@min_date AS varchar(30))

-- while the oldest date in the history is older than the cleanup date
WHILE (@min_date < @CleanupDate)
BEGIN   
    -- set the chunk date to be oldest date + chunk days
    SET @ChunkDate = DATEADD(dd, @chunk_days, @min_date)
    PRINT 'Removing history older than ' + CAST( @ChunkDate AS varchar(30))

    -- delete the data up to the last chunk date
    EXECUTE msdb.dbo.sp_delete_backuphistory @oldest_date = @ChunkDate
    
    -- checkpoint the database so log can be truncated
    IF (@recovery_model = 'SIMPLE')
    BEGIN
        PRINT 'CHECKPOINT'
        CHECKPOINT
    END

    -- get the oldest date in the history
    SELECT @min_date = min(backup_finish_date)
    from msdb.dbo.backupset
    PRINT 'Oldest date in history: ' + CAST(@min_date AS varchar(30))
END

-- final cleanup
PRINT 'Running final cleanup older than date: ' + CAST(@CleanupDate AS varchar(30))
EXECUTE msdb.dbo.sp_delete_backuphistory @oldest_date = @CleanupDate
