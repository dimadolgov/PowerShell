$vmHosts = get-vmhost 
    $VIB = "/vmfs/volumes/xxxxxxxx.vib"
    foreach ($vmhost in $vmhosts)
    {
        Write-Host **Installing VIB on $vmhost ** -ForegroundColor Cyan
        Set-VMhost $vmhost -State maintenance -Evacuate -vsandatamigrationmode EnsureAccessibility | Out-Null
        $esxcli = get-vmhost $vmhost | Get-EsxCli
        $esxcli.software.vib.install($null,$false,$false,$false,$false,$true,$null,$null,"$VIB") | Out-Null
        Write-Host **Rebooting $vmhost ** -ForegroundColor Cyan
        Restart-VMHost -VMHost $vmHost -Confirm:$false | Out-Null
        do 
                {   Start-Sleep 60
                    $ConnectionState = (get-vmhost $vmhost).ConnectionState
                    Write-Host "waiting for Host $vmhost to Reboot" -ForegroundColor Green
                }
            until ($ConnectionState -eq "Maintenance")
            Set-VMhost $vmhost -State Connected 
            Write-Host "Host $vmhost Back Online" -ForegroundColor Green
    }
