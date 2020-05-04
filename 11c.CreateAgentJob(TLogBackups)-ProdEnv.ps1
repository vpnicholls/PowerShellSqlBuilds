<# 
    Adapted from 
    - http://stuart-moore.com/adding-sql-server-jobs-using-powershell/ and 
    - http://sqlmag.com/powershell/add-sql-server-job-failure-notifications-powershell
#>

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

$ComputerName = "Server"
$InstanceName = "Instance"
$ServerName = "$ComputerName\$InstanceName"

# Create instance object
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName

# Set variables for "job server" and operator
$JobServer = $Instance.JobServer
$Operator = New-Object Microsoft.SqlServer.Management.Smo.Agent.Operator ($JobServer, 'SqlServerMonitoring')

# Set backup directory and output filepath
$BackupDirectory = 'H:\SQL-BACKUPS'
$Seconds = 0

$Databases = $Instance.Databases | Where {$_.IsSystemObject -eq $false} | Select Name

if ($Databases)
{
    foreach ($Database in $Databases)
    {
        # Set full backup path and file name
        $DatabaseName = $Database.Name
        #$FilePath = $BackupDirectory + '\' + $Database + '_LiteSpeed.BAK'
        $OutputFileName = "H:\SQL-JOBLOGS\LS_TLog_Backup_$DatabaseName.log"

        #As this is a new job, we create a handle on the job and then create the job. If you look on your SQL instance now you'll see a job without steps, schedules or notifications.
        $Job = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.Job -argumentlist $Instance.JobServer, "TLogBackup_$DatabaseName"
        $Job.OperatorToEmail = $Operator.Name
        $Job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
        $Job.EventLogLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::Never
        $Job.Create()
        $Job.ApplyToTargetServer("(local)")

        # Create step to perform backup and verify database
        $JobStep = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobStep -argumentlist $Job, "Backup TLog"
        $JobStep.SubSystem = "TransactSql"
        $JobStep.Command = 
@"
--  TLOG BACKUP

-- Set the DB name

DECLARE @DBName varchar(256)
SET @DBName = '$DatabaseName'

DECLARE @logfilename varchar(256)  -- To use as the backup file name
DECLARE @TodayDate varchar(15) -- To use for todays date
DECLARE @sqlstring varchar(255)

SET @sqlstring = 'DECLARE @fname varchar(128) USE ' + @dbname + '; SELECT @fname = name FROM sys.database_files WHERE type_desc = ''LOG''' +
'PRINT @fname DBCC SHRINKFILE (@fname, 2048)'

EXEC(@sqlstring)

SET @TodayDate = CAST(DATEPART(YEAR, GETDATE()) AS VARCHAR(10)) 
+ REPLACE(STR(CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(10)), 2, 0), ' ', '0') 
+ REPLACE(STR(CAST(DATEPART(DAY, GETDATE()) AS VARCHAR(10)), 2, 0), ' ', '0')
+ REPLACE(STR(CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(10)), 2, 0), ' ', '0')
+ REPLACE(STR(CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(10)), 2, 0), ' ', '0')

SET @logfilename = 'G:\BACKUPS\TLog\' + @DBName + '\' + @DBName + '_' + @TodayDate + '_LiteSpeed.Trn'

EXEC master.dbo.xp_backup_log 
    @database = @DBName, 
    @filename = @logfilename, 
    @INIT = 1, 
    @logging = 1

EXEC master.dbo.xp_restore_verifyonly 
    @filename = @logfilename, 
    @filenumber = 1
"@
        $JobStep.DatabaseName = "Master"
        $JobStep.OnSuccessAction = "QuitWithSuccess"
        $JobStep.OnFailAction = "QuitWithFailure"
        $JobStep.OutputFileName = $OutputFileName # Still trying to work out how to have this append to the existing file
        $JobStep.Create()

        #Now add a schedule to our job to finish it off
        $JobSchedule =  New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobSchedule -argumentlist $Job, "Daily Full Backup: $DatabaseName"

        #Need to use the built in types for Frequency, in this case we'll run it every day
        $JobSchedule.FrequencyTypes =  [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Daily

        #As we've picked daily, this will repeat every day
        $JobSchedule.FrequencyInterval = 1
        $JobSchedule.FrequencySubDayInterval = 15
        $JobSchedule.FrequencySubDayTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencySubDayTypes]::Minute

        # Need to tell SQL when during the day we want to acutally run it. This is a timespan base on 00:00:00 as the start.
        $TimeSpan1 = New-TimeSpan -hours 23 -minutes 30 -seconds $Seconds
        $TimeSpan2 = New-TimeSpan -hours 22 -minutes 45 -seconds 00
        $JobSchedule.ActiveStartTimeofDay = $TimeSpan1
        $JobSchedule.ActiveEndTimeofDay = $TimeSpan2

        #Set the job to be active from now
        $JobSchedule.ActiveStartDate = get-date
        $JobSchedule.Create()

        $Seconds = $Seconds + 30
    }
}
