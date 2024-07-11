function Renew-VMHostCertificate
{
<#
.EXAMPLE
Get-VMHost ESXiName|Renew-VMHostCertificate -RunAsync
Renew-VMHostCertificate -VMHost (Get-VMHost "ESXi") -RunAsync:$true
Get-Cluster "ClusterName"|Get-VMHost|Renew-VMHostCertificate
Get-VMHost ESXiName|Renew-VMHostCertificate
Renew-VMHostCertificate -VMHost (Get-VMHost "ESXi")
#>
param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$VMHost,
        [switch]$RunAsync
    )
begin
{
If(($global:DefaultVIServers).Count -gt 1)
    {
        Write-Error -Message  "Currently  you are connected to more than 1 vCenter, Please disconnect and connect to Respective vCenter" -ErrorAction Stop
    }
elseIf(($global:DefaultVIServers).Count -lt 1)
    {
        Write-Error -Message "You are not connected to vCenter to perform the task" -ErrorAction Stop
    }
$ServiceInstance=Get-View ServiceInstance
$CertMgrID=$ServiceInstance.content.CertificateManager
$CertMgr=Get-View -Id $CertMgrID
}
Process
{
  
try
    {
        $validation=Get-VMHost $VMHost -ErrorAction Stop
    }
catch
    {
        Write-Error -Message "Entered esxi host does not exist in  $global:DefaultVIServer"
    }
If(($validation.ConnectionState -eq "Connected") -or ($validation.ConnectionState -eq "Maintenance"))
    {
        If($RunAsync -eq $true){
            foreach($script:ESXi in $VMHost){$script:task=$CertMgr.CertMgrRefreshCertificates_Task($script:ESXi.extensiondata.moref)}
        }
        else
        {
            foreach($script:ESXi in $VMHost){$script:task=$CertMgr.CertMgrRefreshCertificates($script:ESXi.extensiondata.moref)}
        }
    }
else{Write-error -Message "Action cannot be performed on current state of ESXi" -ErrorAction Stop}
}
End
    {
        Get-Task|?{$_.Name -match "Certificate"}|ft -AutoSize
    }
}


                
Renew-VMHostCertificate -VMHost (Get-VMHost esxi-server-ip)
