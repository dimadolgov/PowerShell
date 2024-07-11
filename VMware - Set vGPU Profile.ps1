# Step 1
# Enter Host
Param (
        [Parameter(Mandatory=$true)] $hostname
    )


# Step 2
# Define and Select vGPU Profile
$vmHost = Get-VMHost $hostname
$vGpuProfiles = $vmhost.ExtensionData.Config.SharedPassthruGpuTypes
$i = 0
foreach ($vGpuProfile in $vGpuProfiles)
{
                Write-Host "[$i] - $vGpuProfile"
                $i++
}
Write-Host "#############################"
do 
{
                try 
                {              
                                $validated = $true
                                $max = $i -1 
                                [int]$vGpuSelectionInt = Read-Host -Prompt "Please choose a vGPU profile (select between 0 - $max)"
                }
                catch {$validated = $false}
}
until (($vGpuSelectionInt -ge 0 -and $vGpuSelectionInt -le $max) -and $validated)
$vGpuSelection = $vGpuProfiles[$vGpuSelectionInt]
Write-Host "You have selected:" $vGpuSelection



# Step 3
# Collect the VM's that need to change the vGPU profile
$vms = Get-VM  | Where-Object PowerState -EQ "PoweredOff"
foreach ($vm in $vms)
{

    $vGPUDevices = $vm.ExtensionData.Config.hardware.Device | Where-Object { $_.backing.vgpu}
                if ($vGPUDevices.Count -gt 0)
                {
                                Write-Host "Remove existing vGPU configuration from VM:" $vm.Name
                                foreach ($vGPUDevice in $vGPUDevices)
                                {
                                                $controllerKey = $vGPUDevice.controllerKey
                                                $key = $vGPUDevice.Key
                                                $unitNumber = $vGPUDevice.UnitNumber
                                                $device = $vGPUDevice.device
                                                $summary = $vGPUDevice.Summary
                                  
                                                $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                                                $spec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
                                                $spec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
                                                $spec.deviceChange[0].operation = 'remove'
                                                $spec.deviceChange[0].device = New-Object VMware.Vim.VirtualPCIPassthrough
                                                $spec.deviceChange[0].device.controllerKey = $controllerKey
                                                $spec.deviceChange[0].device.unitNumber = $unitNumber
                                                $spec.deviceChange[0].device.deviceInfo = New-Object VMware.Vim.Description
                                                $spec.deviceChange[0].device.deviceInfo.summary = $summary
                                                $spec.deviceChange[0].device.deviceInfo.label = $device
                                                $spec.deviceChange[0].device.key = $key
                                                $_this = $VM  | Get-View
                                                $nulloutput = $_this.ReconfigVM_Task($spec)
                                }
                }
    Write-Host "Adding new vGPU configuration from VM:" $vm.Name
    $vmSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
    $vmSpec.deviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (1)
    $vmSpec.deviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
    $vmSpec.deviceChange[0].operation = 'add'
    $vmSpec.deviceChange[0].device = New-Object VMware.Vim.VirtualPCIPassthrough
    $vmSpec.deviceChange[0].device.deviceInfo = New-Object VMware.Vim.Description
    $vmSpec.deviceChange[0].device.deviceInfo.summary = ''
    $vmSpec.deviceChange[0].device.deviceInfo.label = 'New PCI device'
    $vmSpec.deviceChange[0].device.backing = New-Object VMware.Vim.VirtualPCIPassthroughVmiopBackingInfo
    $vmSpec.deviceChange[0].device.backing.vgpu = "$vGpuSelection"
    $vmobj = $vm | Get-View
                $reconfig = $vmobj.ReconfigVM_Task($vmSpec)
    if ($reconfig) {
       $changedVm = Get-VM $vm
        $vGPUDevice = $changedVm.ExtensionData.Config.hardware.Device | Where-Object { $_.backing.vgpu}
       }   
}
