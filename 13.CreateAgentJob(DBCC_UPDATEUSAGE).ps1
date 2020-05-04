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
# $OutputFileName = '...\JobLogs\DBCC_UPDATEUSAGE.log' # Need to programitcally get the error log location 

# Create the diretories if they don't exist
if ((Test-Path (Split-Path $OutputFileName -Parent)) -eq $false)
{
    New-Item $OutputFileName -ItemType Directory
}

# Define databases to be updated (all except tempdb)
$Databases = $Instance.Databases | Where {$_.Name -ne "TempDB"} | Select Name

#As this is a new job, we create a new object and then create it. If you look on your SQL instance now you'll see a job without steps, schedules or notifications
$Job = New-Object Microsoft.SqlServer.Management.SMO.Agent.Job ($JobServer, "DBCC UPDATEUSAGE")
$Job.OperatorToEmail = $Operator.Name
$Job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
$Job.EventLogLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::Never
$Job.Create()
$Job.ApplyToTargetServer("(local)")

# Add job step 1: Run DBCC UPDATEUSAGE for each database (except TempDB)
$JobStep = New-Object Microsoft.SqlServer.Management.Smo.Agent.JobStep ($Job, "Run DBCC UPDATEUSAGE")
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
	
		SELECT @SQL = 'DBCC UPDATEUSAGE  (' +  @dbName + ')  with COUNT_ROWS' 
		PRINT '			***********************************************************************************************************'
		PRINT '			***********************************************************************************************************'
		PRINT getdate()
		print @SQL
		EXECUTE SP_EXECUTESQL @SQL
		print 'DBCC UPDATEUSAGE completed on ' + @dbName
		PRINT '			***********************************************************************************************************'
		PRINT '			***********************************************************************************************************'

		SELECT @dbNo = @dbNo + 1
	END
DROP TABLE #dbNames;
"@
$JobStep.DatabaseName = "naster"
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

<#
    NO JOB SCHEDULE REQUIRED FOR DBCC UPDATEUSAGE
#>