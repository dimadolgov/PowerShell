$vms = Get-VM  | Where-Object { $_.Name -notlike '*vcls*' }
$DRSCluster = Get-DrsClusterGroup | Where-Object Name -Like "*Group*"
$Result = @()
foreach ($Object in $DRSCluster) {
    $ClusterGroupName = $Object.Name
    $ClusterName = $Object.Cluster.Name
    $Members = (Get-DrsClusterGroup -Cluster $ClusterName -Name $ClusterGroupName).Member
    foreach ($Member in $Members) {
        $VMName = $Member.Name
        $VMGroup = $ClusterGroupName
        $Entry = [PSCustomObject]@{
            "VM Name" = $VMName
            "VMGroup" = $VMGroup
        }
        $Result += $Entry
    }
}
$CombinedResult = foreach ($VMInfo in $vms) {
    $Environment = Get-VM $VMInfo.Name | Get-Annotation | Where-Object Name -eq 'Environment' | Select-Object -ExpandProperty Value
    $Importance = Get-VM $VMInfo.Name | Get-Annotation | Where-Object Name -eq 'Importance' | Select-Object -ExpandProperty Value
    $Notes = $VMInfo.Notes
    $Site = (Get-SpbmEntityConfiguration -VM $VMInfo).StoragePolicy.name
    $Datastore = (Get-Datastore -VM $VMInfo | Select-Object -ExpandProperty Name) -join ','
    $VMGroupInfo = $Result | Where-Object { $_."VM Name" -eq $VMInfo.Name }
    [PSCustomObject]@{
        "Name" = $VMInfo.Name
        "Site" = $Site 
        "Datastore" = $Datastore
        "Notes" = $Notes
        "Importance" = $Importance
        "Environment" = $Environment
        "VMGroup" = $VMGroupInfo.VMGroup
    }
}
$exportPath = "c:\temp\Results.csv"
$CombinedResult | Export-Csv -Path $exportPath -NoTypeInformation -Encoding UTF8
