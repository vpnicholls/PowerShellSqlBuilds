# Import the server manager module for PowerShell
Import-Module servermanager -DisableNameChecking

# Add the desired Windows features
Add-WindowsFeature Telnet-Client, WAS, SNMP-Services, RSAT-Clustering, Multipath-IO, NET-Framework-Core

# Add the desired Windows roles
Add-WindowsFeature AS-NET-Framework, AS-ENT-Services, AS-Incoming-Trans, AS-Outgoing-Trans

# Restart server (Would probably be a good idea to set a variable for this and reboot based on the variable)
##Restart-Computer localhost -Force