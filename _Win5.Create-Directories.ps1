# Define directory names
$Mount = "A:\Mount-1_"
$DirectoryLogs = "$Mount`Logs\Logs\"
$DirectoryData = "$Mount`Data\Data\"
$DirectoryTempDB = "$Mount`TempDB\TempDB\"
#$DirectoryBackups = "$Mount`Backups\Backups\"

New-Item -Path $DirectoryLogs -ItemType Directory
New-Item -Path $DirectoryData -ItemType Directory
New-Item -Path $DirectoryTempDB -ItemType Directory
#New-Item -Path $DirectoryBackups -ItemType Directory
