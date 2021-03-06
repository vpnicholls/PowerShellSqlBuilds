# Adapted from http://sqlmag.com/powershell/set-operators-and-alerts-powershell

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

$ServerName = "Server"
$InstanceName = "Instance"
$PortNumber = "2250"

# Create server object where the databases are to be created
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') "$ServerName\$InstanceName"

# Define variables
$Operator = 'SqlServerMonitoring'
$Severities = 15..25
$Message = "Check $ServerName,$PortNumber"
$Message

# Create agent alerts
foreach ($Severity in $Severities) {
    $Name = "$ServerName,$PortNumber`: Severity $Severity"
    $Alert = New-Object ('Microsoft.SqlServer.Management.Smo.Agent.Alert') ($Instance.JobServer, $Name)
    $Alert.Severity = $Severity
    $Alert.IncludeEventDescription = 'NotifyEmail'
    $Alert.Create()
    $Alert.AddNotification($Operator, [Microsoft.SqlServer.Management.Smo.Agent.NotifyMethods]::NotifyEmail)
    $Alert.NotificationMessage = $Message
    $Alert.DelayBetweenResponses = 900
    $Alert.Alter()
}