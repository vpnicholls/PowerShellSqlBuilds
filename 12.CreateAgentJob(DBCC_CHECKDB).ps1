<# 
    Adapted from 
    - http://stuart-moore.com/adding-sql-server-jobs-using-powershell/ and 
    - http://sqlmag.com/powershell/add-sql-server-job-failure-notifications-powershell
    - http://blog.waynesheffield.com/wayne/archive/2013/02/a-month-of-powershell-day-24-jobserver-jobs/
#>

# Load SMO assemblies
#[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create instance object
$Instance = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Set variables for "job server" and operator
$JobServer = $Instance.JobServer
$Operator = New-Object Microsoft.SqlServer.Management.Smo.Agent.Operator ($JobServer, 'SqlServerMonitoring')

# Set output filepath
# $OutputFileName = '...\JobLogs\DBCC_CHECKDB.log' # Need to programmatically get error log location

# Create the diretories if they don't exist
if ((Test-Path (Split-Path $OutputFileName -Parent)) -eq $false)
{
    New-Item $OutputFileName -ItemType Directory
}

# Define databases to be checked (all except tempdb)
$Databases = $Instance.Databases | Where {$_.Name -ne "TempDB"} | Select Name

#As this is a new job, we create a new object and then create it. If you look on your SQL instance now you'll see a job without steps, schedules or notifications
$Job = New-Object Microsoft.SqlServer.Management.SMO.Agent.Job ($JobServer, "DBCC CHECKDB")
$Job.OperatorToEmail = $Operator.Name
$Job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
$Job.EventLogLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::Never
$Job.Create()
$Job.ApplyToTargetServer("(local)")

# Add job step 1: Run DBCC CHECKDB for each database (except TempDB)
$JobStep = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobStep ($Job, "Run DBCC CHECKDB")
$JobStep.SubSystem = "TransactSql"
$JobStep.Command = @"
CREATE Table #dbNames(dbNo int IDENTITY,
			dbName nvarchar(100))

INSERT INTO #dbNames(dbName)
SELECT Name 
FROM SYS.DATABASES WHERE NAME <> 'tempdb'

DECLARE @DBno int
DECLARE @MaxdbNo int
DECLARE @DBName nvarchar(100)
DECLARE @SQL nvarchar(500)

SELECT @MaxdbNo = Max(dbNo) FROM #dbNames

SELECT @dbNo = 1
WHILE @dbNo <= @MaxdbNo
	BEGIN
		SELECT @dbName = dbName
		FROM  #dbNames 
		WHERE dbNo = @dbNo
	
		SELECT @SQL = 'DBCC CHECKDB  (' +  @dbName + ')  with NO_INFOMSGS, DATA_PURITY' 
		print @SQL
		EXECUTE SP_EXECUTESQL @SQL
		print 'DBCC CHECKDB completed on ' + @dbName
		print '			***********************************************************************************************************'
		print '			***********************************************************************************************************'

		SELECT @dbNo = @dbNo + 1
	END
DROP TABLE #dbNames;
"@
$JobStep.DatabaseName = "master"
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
$JobSchedule =  New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobSchedule -argumentlist $Job, "DBCC CHECKDB Weekly"

#Need to use the built in types for frequency and frequency interval In this case we'll run it weekly on Sundays.
$JobSchedule.FrequencyTypes = [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Weekly
$JobSchedule.FrequencyInterval = [Microsoft.SqlServer.Management.Smo.Agent.WeekDays]::Sunday

# Run every 1 week
$JobSchedule.FrequencyRecurrenceFactor = 1

<#
Need to tell SQL when during the day we want to acutally run it. This is a timespan base on 00:00:00 as the start.
Here we're saying to run it at 21:00. You could combine these lines, but I've left them seperate to make it easier to read.
#>
$TimeSpan1 = New-TimeSpan -hours 21 -minutes 30
$JobSchedule.ActiveStartTimeofDay = $TimeSpan1

#Set the job to be active from now
$JobSchedule.ActiveStartDate = get-date

$JobSchedule.Create()
