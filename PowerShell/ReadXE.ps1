# Example call
#.\ReadXE -DatabaseName PaycircleStats -TableName ProcExecutions20240522 -XEPath "C:\Users\ROBER\Documents\TheAccessGroup\Project Dawn\Paycircle\XEFiles\20240522\*.xel" -StartDate "2024-05-22 00:00:00.0000000 +01:00" -EndDate "2024-05-23 00:00:00.0000000 +01:00"

param (
    [string]$SharedPath = "C:\Program Files\Microsoft SQL Server\160\Shared",
    [string]$SqlInstanceName = ".",
    [string]$DatabaseName = "tempdb",
    [string]$SchemaName = "dbo",
    [string]$TableName = "rpc_completed",
    [string]$XEPath,
    [datetime]$StartDate,
    [datetime]$EndDate
)

$xeCore = [System.IO.Path]::Combine($SharedPath, "Microsoft.SqlServer.XE.Core.dll");
$xeLinq = [System.IO.Path]::Combine($SharedPath, "Microsoft.SqlServer.XEvent.Linq.dll");
Add-Type -Path $xeLinq;

if( [System.IO.File]::Exists($xeCore) )
{
    Add-Type -Path $xeCore;
}

# create target table
$connectionString = "Data Source=$SqlInstanceName;Initial Catalog=$DatabaseName;Integrated Security=SSPI"
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
$command = New-Object System.Data.SqlClient.SqlCommand(@"
CREATE TABLE $SchemaName.$TableName (
    event_id int
    , event nvarchar(20)
	, proc_name nvarchar(300)
	, duration bigint
	, cpu_time bigint
	, logical_reads bigint
	, physical_reads bigint
	, writes bigint
	, row_count bigint
	, statement nvarchar(max)
    , batch_text nvarchar(max)
	, timestamp datetimeoffset
    , constraint PK_$TableName
        primary key clustered (event_id asc)
);
"@, $connection)
$connection.Open()
[void]$command.ExecuteNonQuery()
$connection.Close()

# data table for SqlBulkCopy
$dt = New-Object System.Data.DataTable
[void]$dt.Columns.Add("event_id", [System.Type]::GetType("System.Int32"))
[void]$dt.Columns.Add("event", [System.Type]::GetType("System.String"))
$dt.Columns["event"].MaxLength = 20
[void]$dt.Columns.Add("proc_name", [System.Type]::GetType("System.String"))
$dt.Columns["proc_name"].MaxLength = 300
[void]$dt.Columns.Add("duration", [System.Type]::GetType("System.Int64"))
[void]$dt.Columns.Add("cpu_time", [System.Type]::GetType("System.Int64"))
[void]$dt.Columns.Add("logical_reads", [System.Type]::GetType("System.Int64"))
[void]$dt.Columns.Add("physical_reads", [System.Type]::GetType("System.Int64"))
[void]$dt.Columns.Add("writes", [System.Type]::GetType("System.Int64"))
[void]$dt.Columns.Add("row_count", [System.Type]::GetType("System.Int64"))
[void]$dt.Columns.Add("statement", [System.Type]::GetType("System.String"))
$dt.Columns["statement"].MaxLength = -1
[void]$dt.Columns.Add("batch_text", [System.Type]::GetType("System.String"))
$dt.Columns["batch_text"].MaxLength = -1
[void]$dt.Columns.Add("timestamp", [System.Type]::GetType("System.DateTimeOffset"))

$events = new-object Microsoft.SqlServer.XEvent.Linq.QueryableXEventData($XEPath)

# import XE events from file(s)
$bcp = New-Object System.Data.SqlClient.SqlBulkCopy($connectionString)
$bcp.DestinationTableName = "$SchemaName.$TableName"
$eventCount = 0
$batchCount = 0

$tz = [TimeZoneInfo]::FindSystemTimeZoneById('GMT Standard Time')

$StartDateDiff = $tz.GetUtcOffset($StartDate)
$EndDateDiff = $tz.GetUtcOffset($EndDate)

$StartDateOffset = [DateTimeOffset]::new($StartDate.Ticks, $StartDateDiff)
$EndDateOffset = [DateTimeOffset]::new($EndDate.Ticks, $EndDateDiff)

foreach($event in $events) {
    if (($event.Timestamp -ge $StartDateOffset) -and ($event.Timestamp -le $EndDateOffset)) {
        $eventCount += 1
        $row = $dt.NewRow()
         $dt.Rows.Add($row)
        $row["event_id"] = $eventCount
        $row["event"] = $event.Name
        $row["proc_name"] = $event.Fields["object_name"].Value
        $row["duration"] = $event.Fields["duration"].Value
        $row["cpu_time"] = $event.Fields["cpu_time"].Value
        $row["logical_reads"] = $event.Fields["logical_reads"].Value
        $row["physical_reads"] = $event.Fields["physical_reads"].Value
        $row["writes"] = $event.Fields["writes"].Value
        $row["row_count"] = $event.Fields["row_count"].Value
        $row["statement"] = $event.Fields["statement"].Value
        $row["batch_text"] = $event.Fields["batch_text"].Value
        $row["timestamp"] = $event.Timestamp
        if($eventCount % 10000 -eq 0) {
            $bcp.WriteToServer($dt)
            $dt.Rows.Clear()
            $batchCount += 1
        }
    }
}
$bcp.WriteToServer($dt) # write last batch
$batchCount += 1
Write-Host "$eventCount records imported"
Write-Host "$batchCount batches imported"
