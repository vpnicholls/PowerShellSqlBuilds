# Adapted from http://sqlmag.com/powershell/set-operators-and-alerts-powershell

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Set the server to script from 
$ComputerName = "Server"
$InstanceName = "Instance"
$ServerName = $ComputerName + "\" + $InstanceName
$DelayBetweenResponses = 900 # 5 mins = 300s; 15 mins = 900s

# Create server object where the databases are to be created
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName

# Define variables
$Operator = 'SqlServerMonitoring'

# SQL Server Wait Statistics - Lock Waits

$Name = "SQL Server Wait Statistics - Lock Waits"
$Message = "Blocking is occurring on $ComputerName. You can use activity monitor to identify the blocker."
$AlertName = $Instance.JobServer.Alerts[$Name]
$PerformanceCondition = "MSSQL`$$ComputerName`:Wait Statistics|Lock waits|Waits in progress|>|0"

if ($AlertName)
{
    $AlertName.Drop()
}
$Alert = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.Alert') ($Instance.JobServer, $Name)
$Alert.PerformanceCondition = $PerformanceCondition
$Alert.IncludeEventDescription = 'NotifyEmail'
$Alert.Create()
$Alert.AddNotification($Operator, [Microsoft.SqlServer.Management.Smo.Agent.NotifyMethods]::NotifyEmail)
$Alert.NotificationMessage = $Message
$Alert.DelayBetweenResponses = $DelayBetweenResponses
$Alert.Alter()

# SQL Server Wait Statistics - Lock Waits Cumulative

$Name = "SQL Server Wait Statistics - Lock Waits Cumulative"
$Message = "Check locks on $ComputerName."
$AlertName = $Instance.JobServer.Alerts[$Name]
$PerformanceCondition = "MSSQL`$$ComputerName`:Locks|Lock Wait Time (ms)|_Total|>|10000"

if ($AlertName)
{
    $AlertName.Drop()
}
$Alert = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.Alert') ($Instance.JobServer, $Name)
$Alert.PerformanceCondition = $PerformanceCondition
$Alert.IncludeEventDescription = 'NotifyEmail'
$Alert.Create()
$Alert.AddNotification($Operator, [Microsoft.SqlServer.Management.Smo.Agent.NotifyMethods]::NotifyEmail)
$Alert.NotificationMessage = $Message
$Alert.DelayBetweenResponses = $DelayBetweenResponses
$Alert.Alter()