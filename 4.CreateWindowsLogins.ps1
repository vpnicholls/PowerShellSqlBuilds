# Adapted from http://bi-bigdata.com/2013/07/14/powershell-db-login/

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create server object where the databases are to be created5
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Define the Windows logins to be created
$WindowsLogins = @("myDomain\WindowsLogin1", "myDomain\WindowsLogin")

# Create each SQL Server login as defined above
foreach ($WindowsLogin in $WindowsLogins) 
{
    # Create and enable the login with the necessary properties; Possible LoginTypes are (0) WindowsUser, (1) WindowsGroup, (2) SqlLogin, (3) Certificate, (4) AsymmetricKey
    $Login = new-object ('Microsoft.SqlServer.Management.Smo.Login') ($Instance, $WindowsLogin)
    $Login.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::WindowsUSer

    # Create the SQL Server login
    $Login.Create()

    # Add to sysadmin server role if it's a DBA Windows Login
    if ($Login.Name -like "myDomainDBAs") {
        $Login.AddToRole('sysadmin')
    }
}