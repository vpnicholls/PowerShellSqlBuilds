
# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Set variables
[Int64]$InitialSizeKB = (2048 * 1024)
[Int64]$MaxSizeKB = (2048 * 1024)
[Int64]$FileGrowthKB = (2048 * 1024)
[string]$GrowthType = 'None' # Options = "None", "Percent" or "KB"

# Set the server to script from 
$ComputerName = "Server"
$InstanceName = "Instance"
$ServerName = "$ComputerName\$InstanceName"

# Get handles on server, tempdb and filegroup objects
$Instance = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Server -ArgumentList $ServerName
$Database = $Instance.Databases["TempDB"]
$FileGroupName = "PRIMARY"
$FileGroup = $Database.FileGroups[$FileGroupName]
$Files = $FileGroup.Files

foreach ($File in $Files)
{
    $File.Size = $InitialSizeKB
    $File.MaxSize = $MaxSizeKB
    $File.GrowthType = $GrowthType
    if ($GrowthType -ne "None")
    {
        $File.Growth = $FileGrowthKB
    }
    $File.Alter()
}

# Get-Service -name 'mssql$mssqlserver2012' | restart-service -Force
