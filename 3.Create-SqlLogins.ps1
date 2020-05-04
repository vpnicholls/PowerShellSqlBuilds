# Adapted from http://bi-bigdata.com/2013/07/14/powershell-db-login/

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create server object where the databases are to be created5
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"
# Define the SQL Server logins to be created
$SqlLogins = @("Login1", "Login2", "Login3")

# Create each SQL Server login as defined above
foreach ($SqlLogin in $SqlLogins) 
{
    # Create and enable the login with the necessary properties
    $Login = new-object ('Microsoft.SqlServer.Management.Smo.Login') ($Instance, $SqlLogin)
    $Login.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::SqlLogin
    $Login.PasswordExpirationEnabled = $false
    $Login.PasswordPolicyEnforced = $true

    # Have the user enter the password as a secure string
    $Password = Read-Host "Enter the password for $SqlLogin" -AsSecureString

    # Create the SQL Server login
    $Login.Create($Password)
}




