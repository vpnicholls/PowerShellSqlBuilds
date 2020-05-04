# From http://sqlmag.com/powershell/script-your-database-mail-setup

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create server object where the advanced options are to be enabled
$Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Enable and save changes
$Server.Configuration.ShowAdvancedOptions.ConfigValue = 1
$Server.Configuration.Alter()

# Set desired config and save changes
$Server.Configuration.BlockedProcessThreshold.ConfigValue = 20
$Server.Configuration.XpCmdShellEnabled.ConfigValue = 1
$Server.Configuration.MaxDegreeOfParallelism.ConfigValue = 4
$Server.Configuration.MaxServerMemory.ConfigValue = (4 * 1024)
$Server.Configuration.Alter()