# Adapted from http://sqlmag.com/powershell/script-your-database-mail-setup

# Load SMO assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

# Create server object where the databases are to be created5
$Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') "Server\Instance"

# Enabled Database Mail
$Server.Configuration.DatabaseMailEnabled.ConfigValue = 1
$Server.Configuration.Alter()

$mail = $svr.Mail

$acct = new-object ('Microsoft.SqlServer.Management.Smo.Mail.MailAccount') ($mail, 'sqldba')
$acct.Description = 'Database Administrator Email'
$acct.DisplayName = 'Database Administrator'
$acct.EmailAddress = 'sqldba@example.com'
$acct.ReplyToAddress = 'sqldba@example.com'
$acct.Create()

$mlsrv = $acct.MailServers
$mls = $mlsrv.Item(0)
$mls.Rename('smtpsrv.example.com')
$mls.EnableSsl = 'False'
$mls.UserName = ''
$mls.Alter()
$acct.Alter()

$mlp = new-object ('Microsoft.SqlServer.Management.Smo.Mail.MailProfile') ($mail, 'DBAMail', 'Database Administrator Mail Profile')
$mlp.Create()
$mlp.AddAccount('sqldba', 1)
$mlp.Alter()

# Enable email alerts on SQL Agent
$js.AgentMailType = [Microsoft.SqlServer.Management.Smo.Agent.AgentMailType]::DatabaseMail
$js.DatabaseMailProfile = 'DBAAlertsMail'
$js.Alter()