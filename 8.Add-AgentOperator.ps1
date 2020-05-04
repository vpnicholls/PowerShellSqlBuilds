# Adapted from http://sqlmag.com/powershell/set-operators-and-alerts-powershell

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create server object where the databases are to be created
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Define variables
$Operator = 'SqlServerMonitoring'
$Email = 'sql@mydomain.com'

# Create Operator
$Operator = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.Operator') ($Instance.JobServer,$Operator)
$Operator.EmailAddress = $email
$Operator.PagerDays = 'EveryDay'
$Operator.WeekdayPagerStartTime = '00:00:00'
$Operator.WeekdayPagerEndTime = '23:59:59'
$Operator.SaturdayPagerStartTime = '00:00:00'
$Operator.SaturdayPagerEndTime = '23:59:59'
$Operator.SundayPagerStartTime = '00:00:00'
$Operator.SundayPagerEndTime = '23:59:59'

$Operator.Create()

<#
$Operator | fl *
#>