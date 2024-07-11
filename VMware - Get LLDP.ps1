$VMHosts = Get-VMHost 
$CombinedResult = foreach ($VMHost in $VMHosts)
{
    $NetSystem = Get-View $VMHost.ExtensionData.ConfigManager.NetworkSystem
    $esxcli = $VMHost | Get-EsxCli -V2
    $dist_switches = $esxcli.network.vswitch.dvs.vmware.list.Invoke()
    foreach ($Pnic in $VMHost.ExtensionData.Config.Network.Pnic | Where-Object Device -NotLike "*vusb0*") 
    {
        $vmnicDevice = $NetSystem.QueryNetworkHint($Pnic.Device).Device
        $dvSwitch = ($dist_switches | Where-Object {$_.uplinks -contains $vmnicDevice}).Name
        
        [PSCustomObject]@{
            "Cluster" = $VMHost.Parent
            "ESXi" = ($VMHost.name).Split(".")[0]
            "VMNIC" = $vmnicDevice
            "DvSwitch" = $dvSwitch
            "Switch Port" = $NetSystem.QueryNetworkHint($Pnic.Device).LldpInfo.PortId
            "Switch MAC" = $NetSystem.QueryNetworkHint($Pnic.Device).LldpInfo.ChassisId
            "Switch Name" = ($NetSystem.QueryNetworkHint($Pnic.Device).LldpInfo.Parameter | Where-Object { $_.Key -eq 'System Name' }).Value
            "Speed" = ($Pnic).LinkSpeed.speedmb
        }
    }
}
$CombinedResult | Sort-Object ESXi,vmnic | Format-Table -AutoSize
