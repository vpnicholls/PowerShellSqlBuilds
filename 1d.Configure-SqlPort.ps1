# Load required assemblies
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null

# Set the server to script from 
$ComputerName = "LT001"
$InstanceName = "MSSQLSERVER2017"
$ServerName = $ComputerName + "\" + $InstanceName;

#Set other variables
$PortNumber = "1433"

# Configure
$Server = New-Object ('Microsoft.SqlServer.Management.Smo.WMI.ManagedComputer') $ComputerName
$Instance = $Server.ServerInstances[$InstanceName]
$Protocol = $Instance.ServerProtocols['Tcp']
$Protocol.IsEnabled = $true
$IPAddress = $Protocol.IPAddresses['IPAll']
$IPAddress.IPAddressProperties['TcpDynamicPorts'].Value = ''
$IPAddress.IPAddressProperties['TcpPort'].Value = $PortNumber
$Protocol.Alter()