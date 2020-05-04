# Define directory names
$DirectoryLogs = "E:\MSSQL\Logs\"
$DirectoryData = "F:\MSSQL\Data\"
$DirectoryTempDB = "G:\MSSQL\TempDB\"
$DirectoryBackups = "H:\MSSQL\Backups\"

New-Item -Path $DirectoryLogs -ItemType Directory
New-Item -Path $DirectoryData -ItemType Directory
New-Item -Path $DirectoryTempDB -ItemType Directory
New-Item -Path $DirectoryBackups -ItemType Directory
