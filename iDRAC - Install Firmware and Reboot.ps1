# Get VMware Server Object based on name passed as arg
$ESXiServers = Get-Content "C:\Temp\xx.txt"
    
    foreach ($ESXiServer in $ESXiServers) 
        {
            $idrac = $ESXiServer.Substring(0, $ESXiServer.IndexOf(".") + 0) + "r"
            Write-Host "Rebooting iDRAC $idrac" -ForegroundColor Green
            Invoke-ResetIdracREDFISH -idrac_ip $idrac -idrac_username "XXXX" -idrac_password "XXXX"
            Write-Host "Entering $ESXiServer to Maintanance Mode" -ForegroundColor Green
            Set-VMhost $ESXiServer -State maintenance -Evacuate -vsandatamigrationmode EnsureAccessibility | Out-Null
            Write-Host "Installing Firmware on $ESXiServer" -ForegroundColor Green
            Set-DeviceFirmwareSimpleUpdateREDFISH -idrac_ip $idrac -idrac_username "XXXX" -idrac_password "XXXX" -image_directory_path C:\temp\ -image_filename "Serial-ATA_Firmware_8KVKG_WN64_DZ02_A00.exe" 
            # Exit Maintanance Mode
            do 
                {   sleep 10
                    $ConnectionState = (get-vmhost $ESXiServer).ConnectionState
                    Write-Host "waiting for Host $ESXiServer to Exit Maintanance Mode" -ForegroundColor Green
                }
            until ($ConnectionState -eq "Maintenance")
            Set-VMhost $ESXiServer -State Connected | Out-Null
            Write-Host "Host $ESXiServer Upgraded" -ForegroundColor Green 
            Start-Sleep 10
        }
