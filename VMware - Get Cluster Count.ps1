$clusters = Get-Cluster | sort
$clusterInfo = @()
$datacenters = Get-Datacenter
foreach ($datacenter in $datacenters) {
    $datacenterName = $datacenter.Name
    $clusters = Get-Cluster -Location $datacenter
    foreach ($cluster in $clusters) {
        $clusterName = $cluster.Name
        $esxiCount = $cluster | Get-VMHost | Measure-Object | Select-Object -ExpandProperty Count
        $vmCount = $cluster | Get-VM | Measure-Object | Select-Object -ExpandProperty Count
        $clusterObj = [PSCustomObject]@{
            'Datacenter' = $datacenterName
            'Cluster' = $clusterName
            'ESXi' = $esxiCount
            'VM Count' = $vmCount
        }
        $clusterInfo += $clusterObj
    }
}
$clusterInfo | Format-Table -AutoSize
