$vms = Get-Content -Path C:\Temp\prod.txt # Should Contain VM Names
$dst_cluster = Get-Cluster # Destination Cluster

$dst_Datastore = get-cluster $dst_cluster | Get-Datastore -Name *vsan*
    foreach ($vm in $vms)
        {
        Clear-Host
        $src_cluster = (Get-Cluster -VM $vm).name
        if ($null -ne ((get-vm $vm | Get-TagAssignment | Where-Object tag -Like "$src_cluster*").tag))
            {
                $SourceTAG = (get-vm $vm | Get-TagAssignment | Where-Object tag -Like "$src_cluster*").tag
                $DestinationTAG = Get-Tag | Where-Object name -Like $SourceTAG.name | Where-Object { $_.Category -like "*$($dst_cluster.name)_DRS*"}
                get-vm $vm | Get-TagAssignment -Tag $SourceTAG | Remove-TagAssignment -Confirm:$false
                get-vm $vm | New-TagAssignment -Tag $DestinationTAG
            }
        $Start_Date = Get-Date -Format "dd/MM  HH:mm:ss"
        $DRSRules = Get-DrsClusterGroup -VM $vm
        if($null -ne $DRSRules)
            {
                Get-DrsClusterGroup -Name $DRSRules -Cluster $src_cluster | Set-DrsClusterGroup -VM $vm -Remove
            }
        Move-VM -VM $vm -Destination $dst_cluster -Datastore $dst_Datastore.name -Confirm:$false | Out-Null
        write-host "vMotion is Started on $vm"
        while (((Get-Task | Select-Object -ExpandProperty ExtensionData).Info | Where-Object EntityName -EQ $vm).State -like "running") 
            {
                $task = (Get-Task | Select-Object -ExpandProperty ExtensionData).Info | Where-Object EntityName -EQ $vm
                Write-Host "vMotion $($task.Progress)%" $vm
                Start-Sleep -Seconds 5
            }
        write-host "vMotion is Completed on $vm"
        if($null -ne $DRSRules)
            {
                $VM_dst = Get-VM $vm
                Get-DrsClusterGroup -Name $DRSRules -Cluster $dst_cluster | Set-DrsClusterGroup -VM $VM_dst -Add
            }
        $End_Date = Get-Date -Format "dd/MM  HH:mm:ss"
        $Size = [math]::Round(((get-vm $vm ).UsedSpaceGB | measure-Object -Sum).Sum)
        $body = @"
        vMotion Complete on $vm
        Start Time: $Start_Date 
        End Time: $End_Date
        VM Size: $Size GB
        DRS Rule: $DRSRules
"@
        Write-Host "Migration Completed on $VM_dst DRS Rule:" $DRSRules.name
        Send-MailMessage -From "xx@xx.com" -to " xx@xx.com " -Body $body -Subject "vMotion Completed" -SmtpServer " xx@xx.com "
        
            for ($i = 10; $i -ge 1; $i--) 
            {
                Write-Host "Starting Next vMotion in:"$i
                Start-Sleep -Seconds 1
            }
        }

