# Enable Remote Desktop: Allow connections from computers running any version of Remote Desktop
(Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace root\cimv2\TerminalServices -Filter "TerminalName='RDP-tcp'").SetUserAuthenticationRequired(0) | Out-Null


# Further work required to get remaining RDP settings

