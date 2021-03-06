# Needs to be created so that service can be the database owner;

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create server object where the databases are to be created5
$Instance = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Retrieve and store the service account
$ServiceAccount = $Instance.ServiceAccount

# Create the associated Windows login;
$Login = new-object ('Microsoft.SqlServer.Management.Smo.Login') ($Instance, $ServiceAccount)
$Login.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::WindowsUser
$Login.Create()
    
# Add to sysadmin server role if it's a DBA Windows Login
$Login.AddToRole('sysadmin')