# Check to make sure both arguments exist
if ($args.count -ne 2) {
    #<vCenter> = Enter vCenter Name 
    #<HostList.txt> = Enter Path to ESXi Hosts
    Write-Host "Usage: reboot-vmcluster.ps1 <vCenter> <HostList.txt>"
    exit
    }
    # Set vCenter and Cluster name from Arg
    $vCenterServer = $args[0]
    $VIHosts = $args[1]
    #option 2 -by cluster
    #$ClusterName = $args[1] 
    # Connect to vCenter
    Connect-VIServer -Server $vCenterServer | Out-Null
    # Get VMware Server Object based on name passed as arg
    $ESXiServers = Get-Content $VIHosts | %{Get-VMHost $_}
    #option 2 - by cluster
    #$ESXiServers = @(get-cluster $ClusterName | get-vmhost)
    # Reboot ESXi Server Function
    Function RebootESXiServer ($CurrentServer) {
    $ServerName = $CurrentServer.Name
    Write-Host "** Rebooting $ServerName **"
    Write-Host "Entering Maintenance Mode"
    Set-VMhost $CurrentServer -State maintenance -Evacuate -vsandatamigrationmode EnsureAccessibility | Out-Null
    $ServerState = (get-vmhost $ServerName).ConnectionState
    if ($ServerState -ne "Maintenance")
    {
    Write-Host "Server did not enter maintanenace mode. Cancelling remaining servers"
    Disconnect-VIServer -Server $vCenterServer -Confirm:$False
    Exit
    }
    Write-Host "$ServerName is in Maintenance Mode"
    Write-Host "Rebooting"
    Restart-VMHost $CurrentServer -confirm:$false | Out-Null
    do {
    sleep 15
    $ServerState = (get-vmhost $ServerName).ConnectionState
    }
    while ($ServerState -ne "NotResponding")
    Write-Host "$ServerName is Down"
    do {
    sleep 60
    $ServerState = (get-vmhost $ServerName).ConnectionState
    Write-Host "Waiting for Reboot ..."
    }
    while ($ServerState -ne "Maintenance")
    Write-Host "$ServerName is back up"
    Write-Host "Exiting Maintenance mode"
    Set-VMhost $CurrentServer -State Connected | Out-Null
    Write-Host "** Reboot Complete **"
    Write-Host ""
    }
    foreach ($ESXiServer in $ESXiServers) {
    RebootESXiServer ($ESXiServer)
    }
    Disconnect-VIServer -Server $vCenterServer -Confirm:$False
    