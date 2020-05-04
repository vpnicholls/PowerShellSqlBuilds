<# 
    Adapted from 
    - http://stuart-moore.com/adding-sql-server-jobs-using-powershell/ and 
    - http://sqlmag.com/powershell/add-sql-server-job-failure-notifications-powershell
    - http://blog.waynesheffield.com/wayne/archive/2013/02/a-month-of-powershell-day-24-jobserver-jobs/
#>

# Create instance object
$Instance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Set variables for "job server" and operator
$JobServer = $Instance.JobServer
$Operator = New-Object Microsoft.SqlServer.Management.Smo.Agent.Operator ($JobServer, 'Monitoring')

# Set output filepath
# $OutputFileName = '...\JobLogs\UpdateStatistics.log' # Need to programatically get error log location

# Create the diretories if they don't exist
if ((Test-Path (Split-Path $OutputFileName -Parent)) -eq $false)
{
    New-Item $OutputFileName -ItemType Directory
}

#As this is a new job, we create a new object and then create it. If you look on your SQL instance now you'll see a job without steps, schedules or notifications
$Job = New-Object Microsoft.SqlServer.Management.SMO.Agent.Job ($JobServer, "DATABASE MAINTENANCE: Update Statistics ")
$Job.OperatorToEmail = $Operator.Name
$Job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
$Job.EventLogLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::Never
$Job.Create()
$Job.ApplyToTargetServer("(local)")

# Add job step 1: Run Update statistics for all user databases for each database (except TempDB)
$JobStep = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobStep ($Job, "Update statistics")
$JobStep.SubSystem = "TransactSql"
$JobStep.Command = @"
EXEC sp_msforeachdb '
USE ?
DECLARE @SQL NVARCHAR(1000) 
DECLARE @DBName varchar(256)

SET @DBName = ''?''

IF @DBName NOT IN (''master'', ''msdb'', ''model'',''tempdb'',''distribution'')
BEGIN

    SELECT @SQL = ''USE ?'' + '';'' + CHAR(13) + ''EXEC sp_updatestats''  + '';''  + CHAR(13) 
    PRINT @SQL 
    EXEC sp_executesql @SQL;

END'
"@
$JobStep.DatabaseName = "Master"
$JobStep.OnSuccessAction = "GoToNextStep"
$JobStep.OnFailAction = "QuitWithFailure"
$JobStep.OutputFileName = $OutputFileName
$JobStep.JobStepFlags = "AppendToLogFile"
$JobStep.Create()

$JobStep.JobStepFlags

# Get the last step so we can set the job to notify on failure
$JobStepCount = $Job.JobSteps.Count
$JobStepIndex = $JobStepCount - 1
$JobStepFinal = $Job.JobSteps[$JobStepIndex]
$JobStepFinal.OnSuccessAction = "QuitWithSuccess"
$JobStepFinal.Alter()

#Now add a schedule to our job to finish it off
$JobSchedule =  New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobSchedule -argumentlist $Job, "Update Statistics Daily"

#Need to use the built in types for frequency and frequency interval In this case we'll run it Daily.
$JobSchedule.FrequencyTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Daily
$JobSchedule.FrequencyInterval = 1

# Run every 1 week
$JobSchedule.FrequencyRecurrenceFactor = 1

<#
Need to tell SQL when during the day we want to acutally run it. This is a timespan base on 00:00:00 as the start.
Here we're saying to run it at 21:00. You could combine these lines, but I've left them seperate to make it easier to read.
#>
$TimeSpan1 = New-TimeSpan -hours 2 -minutes 00
$JobSchedule.ActiveStartTimeofDay = $TimeSpan1

#Set the job to be active from now
$JobSchedule.ActiveStartDate = get-date

$JobSchedule.Create()