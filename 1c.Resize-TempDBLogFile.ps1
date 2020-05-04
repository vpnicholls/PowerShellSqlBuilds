
# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Set variables
[Int64]$InitialSizeKB = (1024 * 1024)
[Int64]$MaxSizeKB = (1024 * 1024)
[Int64]$FileGrowthKB = (1024 * 1024)
[string]$GrowthType = 'KB' # Options = "None", "Percent" or "KB"

# Set the server to script from 
$ComputerName = "Server"
$InstanceName = "Instance"
$ServerName = "$ComputerName\$InstanceName"

# Get handles on server object and tempdb objects
$Instance = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Server -ArgumentList $ServerName
$Database = $Instance.Databases["TempDB"]
$LogFiles = $Database.LogFiles

foreach ($LogFile in $LogFiles)
{
    $LogFile.Size = $InitialSizeKB
    $LogFile.MaxSize = $MaxSizeKB
    $LogFile.GrowthType = $GrowthType
    if ($GrowthType -ne "None")
    {
        $LogFile.Growth = $FileGrowthKB
    }
    $LogFile.Alter()
}

# Get-Service -name 'mssql$mssqlserver2012' | restart-service -Force
