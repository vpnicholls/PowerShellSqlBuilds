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
$Operator = New-Object Microsoft.SqlServer.Management.Smo.Agent.Operator ($JobServer, 'Monitoring')

# Set backup directory and output filepath
$BackupDirectory = 'H:\SQL-BACKUPS'
$OutputFileName = 'H:\SQL-JOBLOGS\BackupUserDatabases.log'

# Set full backup path and file name
$FilePath = $BackupDirectory + '\' + $Database + '_LiteSpeed.BAK'

#As this is a new job, we create a new object and then create it. If you look on your SQL instance now you'll see a job without steps, schedules or notifications
$Job = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.Job -argumentlist $Instance.JobServer, "BACKUP: User Databases"
$Job.OperatorToEmail = $Operator.Name
$Job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
$Job.EventLogLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::Never
$Job.Create()
$Job.ApplyToTargetServer("(local)")


# Truncate log file
$JobStep = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobStep -argumentlist $Job, "Truncate Log Files"
$JobStep.SubSystem = "PowerShell"
$JobStep.Command = 
@"
# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create instance object
`$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName

# Define user databases to be truncate log files for
`$Databases = `$Instance.Databases | Where {`$_.IsSystemObject -eq `$false} | Select Name

# Truncate log files for each user database
ForEach (`$Database in `$Databases)
{
        `$query = "DBCC SHRINKFILE((`$Database)_log)"
        Invoke-Sqlcmd -ServerInstance `$Instance -Query $query
}
"@
$JobStep.DatabaseName = "master"
$JobStep.OnSuccessAction = "GoToNextStep"
$JobStep.OnFailAction = "QuitWithFailure"
$JobStep.OutputFileName = $OutputFileName # Still trying to work out how to have this append to the existing file
$JobStep.Create()

# Backup and verify database
$JobStep = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobStep -argumentlist $Job, "Backup and Verify Database Backups"
$JobStep.SubSystem = "TransactSql"
$JobStep.Command = 
@"
SET NOCOUNT ON
DECLARE @dbname VARCHAR(255)
DECLARE @dumplogname VARCHAR(255)
DECLARE @dumppath VARCHAR(30)
DECLARE @getdate VARCHAR(13)
SET @getdate =CONVERT(VARCHAR(13), GETDATE(), 105)
SELECT @dumppath = '$BackupDirectory'

DECLARE DBCursor CURSOR FOR				
    SELECT name FROM sys.databases WHERE database_id > 4 ORDER BY NAME

OPEN DBCursor
FETCH NEXT FROM DBCursor INTO @dbname

WHILE @@fetch_status = 0
	BEGIN
		SELECT @dumplogname = @dumppath + @dbname + '_Litespeed.BAK'
        PRINT @dumplogname

		EXEC master.dbo.xp_backup_database @database = @dbName, @filename = @dumplogname, @INIT = 1, @FORMAT = 0, @logging = 0, @compressionlevel = 2

		EXEC master.dbo.xp_restore_verifyonly @filename = @dumplogname, @filenumber = 1

		FETCH NEXT FROM DBCursor into @dbname
	END

DEALLOCATE DBCursor
"@
$JobStep.DatabaseName = "Master"
$JobStep.OnSuccessAction = "GoToNextStep"
$JobStep.OnFailAction = "QuitWithFailure"
$JobStep.OutputFileName = $OutputFileName # Still trying to work out how to have this append to the existing file
$JobStep.Create()

# Get the last step so we can set the job to notify on failure
$JobStepCount = $Job.JobSteps.Count
$JobStepIndex = $JobStepCount - 1
$JobStepFinal = $Job.JobSteps[$JobStepIndex]
$JobStepFinal.OnSuccessAction = "QuitWithSuccess"
$JobStepFinal.Alter()

#Now add a schedule to our job to finish it off
$JobSchedule =  New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobSchedule -argumentlist $Job, "Daily User Databases Backup"

#Need to use the built in types for Frequency, in this case we'll run it every day
$JobSchedule.FrequencyTypes =  [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Daily

#As we've picked daily, this will repeat every day
$JobSchedule.FrequencyInterval = 1

<#
Need to tell SQL when during the day we want to acutally run it. This is a timespan base on 00:00:00 as the start.
Here we're saying to run it at 1:00. You could combine these lines, but I've left them seperate to make it easier to read.
#>
$TimeSpan1 = New-TimeSpan -hours 1 -minutes 00
$JobSchedule.ActiveStartTimeofDay = $TimeSpan1

#Set the job to be active from now
$JobSchedule.ActiveStartDate = get-date
$JobSchedule.Create()
