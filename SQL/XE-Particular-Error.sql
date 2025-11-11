CREATE EVENT SESSION [error_978]
ON SERVER
    ADD EVENT sqlserver.error_reported
    (ACTION
     (
         sqlserver.server_instance_name,
         sqlserver.session_id,
         sqlserver.sql_text,
         sqlserver.tsql_frame
     )
     WHERE ([error_number] = (978))
    )
    ADD TARGET package0.event_file
    (SET filename = N'error_978')
WITH
(
    MAX_MEMORY = 4096KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 30 SECONDS,
    MAX_EVENT_SIZE = 0KB,
    MEMORY_PARTITION_MODE = PER_NODE,
    TRACK_CAUSALITY = OFF,
    STARTUP_STATE = ON
);