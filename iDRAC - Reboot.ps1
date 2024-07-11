$ESXiServers = Get-Content "C:\Temp\hosts.txt"
    
    foreach ($ESXiServer in $ESXiServers) 
        {
            Write-Host *** Rebooting iDRAC on $ESXiServer *** -ForegroundColor Cyan         
            Invoke-ResetIdracREDFISH -idrac_ip $ESXiServer -idrac_username "" -idrac_password ""
        }