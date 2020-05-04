# Load assemblies
[void][reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo");

# Set the server to script from 
$ComputerName = "Server"
$InstanceName = "Instance"
$ServerName = $ComputerName + "\" + $InstanceName;

# Get a server object
$Instance = New-Object -TypeName Microsoft.SqlServer.Management.SMO.Server $ServerName

# Set the account variables
$AccountName = "ServerName"
$EmailAddress = $AccountName + "@mydomain.co.nz"
$ReplyTo = "sql@mydomain.co.nz"

# Set the email address to use for the test email
#$TestEmailAddress = "vpnicholls@mydomain.com"

# Set the SQL Agent service display name
$SQLAgentService = "SQL Server Agent ($InstanceName)"

# Enable Database Mail
$Instance.Configuration.ShowAdvancedOptions.ConfigValue = 1
$Instance.Configuration.DatabaseMailEnabled.ConfigValue = 1
$Instance.Configuration.Alter()

# Create Mail object
$Mail = $Instance.Mail

# Create the mail account
$Account = New-Object ('Microsoft.SqlServer.Management.Smo.Mail.MailAccount') ($mail, $AccountName)
$Account.Description = $AccountName
$Account.DisplayName = $AccountName
$Account.EmailAddress = $EmailAddress
$Account.ReplyToAddress = $ReplyTo
$Account.Create()

# Make some necessary amendments
$MailServers = $Account.MailServers
$MailServer = $MailServers.Item(0)
$MailServer.Rename('mail.mydomain.com')
$MailServer.EnableSsl = $false
$MailServer.UserName = ''
$MailServer.Alter()
$Account.Alter()

# Create the mail profile
$MailProfile = New-Object ('Microsoft.SqlServer.Management.Smo.Mail.MailProfile') ($mail, $AccountName, $AccountName)
$MailProfile.Create()
$MailProfile.AddAccount($AccountName, 1)
$MailProfile.Alter()

# Configure the SQL Agent to use dbMail and then restart the SQL Agent service for this to take effect
$Instance.JobServer.AgentMailType = 'DatabaseMail'
$Instance.JobServer.DatabaseMailProfile = $MailProfile
$Instance.JobServer.Alter()

# Cannot be restarted from the local server if the service uses a domain service account (or if it's a cluster); Need to add logic to restart if the account is local;
# $ServerName.ServiceAccount | Restart-Service

# Test the mail profile *** Deprecated in SQL Server 2012; Unable to find an alternative; ***
# $Instance.JobServer.TestMailProfile($MailProfile)

<#
# Alternative method of retrieving service name

Get-WmiObject -ComputerName $hostname `
    -Namespace "$($namespace.__NAMESPACE)\$($namespace.Name)" `
    -Class SqlService |
Where SQLServiceType -eq 1 | Select ServiceName

#>
