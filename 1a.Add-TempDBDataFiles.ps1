
# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

# Set variables
[Int16]$FileCount = 1
[Int16]$maxFileCount = 4
[Int32]$maxFileInitialSizeMB = 2048
[Int32]$maxFileGrowthSizeMB = 2048 
[Int32]$fileGrowthMB = 512
[string]$tempdbFileLocation = "H:\MSSQL\TempDB"

# Set the server to script from 
$ComputerName = "Server"
$InstanceName = "Instance"
$ServerName = "$ComputerName\$InstanceName"

while ($FileCount -lt $maxFileCount)
{
    [string]$FileName = "tempdev$FileCount"

    # Get a server object and a tempdb object
    $Instance = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Server -ArgumentList $ServerName
    $Database = $Instance.Databases["TempDB"]
    $FileGroupName = "PRIMARY"
    $FileGroup = $Database.FileGroups[$FileGroupName]

    $DataFile = New-Object -TypeName Microsoft.SqlServer.Management.SMO.DataFile -ArgumentList $FileGroup, $FileName
    $DataFile.FileName = "$tempdbFileLocation\$Filename.ndf"
    $DataFile.Create()

    $FileCount++ 
}

# Get-Service -name 'mssql$mssqlserver2012' | restart-service -Force
