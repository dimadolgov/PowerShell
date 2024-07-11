$Serials = foreach($esxcli in Get-VMHost | Get-EsxCli -V2){
    $esxcli.hardware.platform.get.Invoke() |
    Select-Object @{N='VMHost';E={$esxcli.VMHost.Name}},VendorName,ProductName,SerialNumber 
}
$Serials
