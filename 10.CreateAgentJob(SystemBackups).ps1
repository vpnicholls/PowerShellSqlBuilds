<# 
    Adapted from 
    - http://stuart-moore.com/adding-sql-server-jobs-using-powershell/ and 
    - http://sqlmag.com/powershell/add-sql-server-job-failure-notifications-powershell
#>

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

# Create instance object
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Set variables for "job server" and operator
$JobServer = $Instance.JobServer
$Operator = New-Object Microsoft.SqlServer.Management.Smo.Agent.Operator ($JobServer, 'Monitoring')

# Set backup directory and output filepath
$Environment = 'UAT'
$BackupDirectory = "\\Server\FileshareBackups\$Environment\System"
# $OutputFileName = '...\JobLogs\BackupSystemDatabases.log' # need to programtically get the error log directory

# Create the diretories if they don't exist
if ((Test-Path $BackupDirectory) -eq $false)
{
    New-Item $BackupDirectory -ItemType Directory
}

if ((Test-Path (Split-Path $OutputFileName -Parent)) -eq $false)
{
    New-Item $OutputFileName -ItemType Directory
}

# Define databases to be backed up
$Databases = @("master", "msdb")

#As this is a new job, we create a new object and then create it. If you look on your SQL instance now you'll see a job without steps, schedules or notifications
$Job = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.Job -argumentlist $Instance.JobServer, "BACKUP: System Databases"
$Job.OperatorToEmail = $Operator.Name
$Job.EmailLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::OnFailure
$Job.EventLogLevel = [Microsoft.SqlServer.Management.SMO.Agent.CompletionAction]::Never
$Job.Create()
$Job.ApplyToTargetServer("(local)")

# Loop through the required databases defined earlier to create the necessary job steps
ForEach ($Database in $Databases)
{
    # Set full backup path and file name
    $FilePath = "$BackupDirectory\$Database`_native_$Environment.BAK"

    # Job step 1 (for this database): Backup database
    $JobStep = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobStep -argumentlist $Job, "Backup $Database"
    $JobStep.Command = "BACKUP DATABASE $Database TO DISK = N'$FilePath' WITH NOFORMAT, INIT,  NAME = N'$Database-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10;"
    $JobStep.DatabaseName = "master"
    $JobStep.OnSuccessAction = "GoToNextStep"
    $JobStep.OnFailAction = "QuitWithFailure"
    $JobStep.OutputFileName = $OutputFileName # Still trying to work out how to have this append to the existing file
    $JobStep.Create()

    # Job step 2 (for this database): Verify backup
    $JobStep = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobStep -argumentlist $Job, "Verify $Database Backup"
    $JobStep.Command = "RESTORE VERIFYONLY FROM DISK = '$FilePath' WITH STATS=10;"
    $JobStep.DatabaseName = "master"
    $JobStep.OnSuccessAction = "GoToNextStep"
    $JobStep.OnFailAction = "QuitWithFailure"
    $JobStep.OutputFileName = $OutputFileName
    $JobStep.JobStepFlags = "AppendToLogFile"
    $JobStep.Create()
}

# Get the last step so we can set the job to notify on failure
$JobStepCount = $Job.JobSteps.Count
$JobStepIndex = $JobStepCount - 1
$JobStepFinal = $Job.JobSteps[$JobStepIndex]
$JobStepFinal.OnSuccessAction = "QuitWithSuccess"
$JobStepFinal.Alter()

#Now add a schedule to our job to finish it off
$JobSchedule =  New-Object -TypeName Microsoft.SqlServer.Management.SMO.Agent.JobSchedule -argumentlist $Job, "Daily System Databases Backup"

#Need to use the built in types for Frequency, in this case we'll run it every day
$JobSchedule.FrequencyTypes =  [Microsoft.SqlServer.Management.SMO.Agent.FrequencyTypes]::Daily

#As we've picked daily, this will repeat every day
$JobSchedule.FrequencyInterval = 1

<#
Need to tell SQL when during the day we want to acutally run it. This is a timespan base on 00:00:00 as the start.
Here we're saying to run it at 21:00. You could combine these lines, but I've left them seperate to make it easier to read.
#>
$TimeSpan1 = New-TimeSpan -hours 21 -minutes 00
$JobSchedule.ActiveStartTimeofDay = $TimeSpan1

#Set the job to be active from now
$JobSchedule.ActiveStartDate = get-date
$JobSchedule.Create()
