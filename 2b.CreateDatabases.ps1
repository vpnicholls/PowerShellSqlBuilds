# Adapted from http://sqlblog.com/blogs/allen_white/archive/2008/04/28/create-database-from-powershell.aspx

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null

# Create server object where the databases are to be created5
$Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Define the databases to be created
$Databases = @("Database1", "Database2", "Database3")

# Create each database as defined above
foreach ($Database in $Databases) 
{
    # Instantiate the database object and add the filegroups
    $db = new-object ('Microsoft.SqlServer.Management.Smo.Database') ($Server, $Database)
    $Filegroup = new-object ('Microsoft.SqlServer.Management.Smo.FileGroup') ($db, 'PRIMARY')
    $db.FileGroups.Add($Filegroup)

    # Once the filegroups have been created", "we can create the files for the database. To create the database the PRIMARY filegroup has to be set to be the default", "so we'll set that here as well.

    # Create the data file
    $DataName = $Database
    $dbDataFile = new-object ('Microsoft.SqlServer.Management.Smo.DataFile') ($Filegroup, $DataName)
    $Filegroup.Files.Add($dbDataFile)
    $dbDataFile.FileName = $Server.Settings.DefaultFile + $DataName + '.mdf'
    $dbDataFile.Size = [double](100.0 * 1024.0)
    $dbDataFile.GrowthType = 'KB'
    $dbDataFile.Growth = [double](100.0 * 1024.0)
    $dbDataFile.IsPrimaryFile = 'True'

    # Now I can create the file for the transaction log. I set this to an initial size of 10MB with 25% growth.

    # Create the log file for
    $LogName = $Database + '_Log'
    $dbLogFile = new-object ('Microsoft.SqlServer.Management.Smo.LogFile') ($db, $LogName)
    $db.LogFiles.Add($dbLogFile)
    $dbLogFile.FileName = $Server.Settings.DefaultLog + $LogName + '.ldf'
    $dbLogFile.Size = [double](50.0 * 1024.0)
    $dbLogFile.GrowthType = 'KB'
    $dbLogFile.Growth = [double](50.0 * 1024.0)

    # We can create the database now. Now it's ready for loading the tables and other objects necessary for the application to work properly.

    # Create the database
    $db.Create()
}

# Update database options where we don't want the defaults
$Server.Databases | Where {$_.IsSystemObject -eq $false} | ForEach {
    $_.RecoveryModel = [Microsoft.SqlServer.Management.Smo.RecoveryModel]::Simple
    $_.IsReadCommittedSnapshotOn = $true
    $_.SetOwner($Server.ServiceAccount, $false)
    $_.Alter()
}