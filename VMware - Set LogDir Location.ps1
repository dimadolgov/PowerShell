#Enter New Datastore Location (ds:///vmfs/volumes/xxxxx)
$New = "[] /vmfs/volumes/xxxxxxxxxxxxxxxxxxxxxxxxxxxxx/ESXi-Logs"

#Get Current Configuration
Get-VMHost | Get-AdvancedSetting -Name Syslog.global.logDir | Select-Object Entity,Value

#Set Values (Add: Cluster\ESXi\Folder\Datacenter)
Get-VMHost -Location "###" | Get-AdvancedSetting -Name Syslog.global.logDir | Set-AdvancedSetting -value $New -Confirm:$False -WhatIf
