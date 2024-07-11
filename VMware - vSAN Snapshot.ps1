#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#
# Create Snapshot on all Powered On and Windows Virual Machines Simultaneously with name "vSAN_Daily_Snap" and deletes older ones #
#---------------------------------------------------------------------------------------------------------------------------------#
#---------------------------------------------------------------------------------------------------------------------------------#

 $VMs = get-vm -Location "vsan cluster"  | Where-Object {($_.PowerState -eq "PoweredOn") -and ($_.Guest -like "*Windows*") }
foreach ($vm in $VMs)
{
    $task = get-vm $vm | New-Snapshot -Name "vSAN_Daily_Snap" -Description "vSAN_Daily_Snap" -RunAsync

        while ((Get-Task -Id $task.id ).State -ne "Success" )
                {
                    Write-Host "waiting for snap $vm"
                    Start-Sleep 2
                }

         get-vm $vm | get-snapshot | Where-Object {($_.Description -Like "vSAN_Daily_Snap") -and ($_.IsCurrent -ne "True")} | Remove-Snapshot -RunAsync -Confirm:$false 
}
