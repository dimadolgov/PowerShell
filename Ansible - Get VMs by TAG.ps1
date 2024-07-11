$tags = @("dev", "test")

$inventoryContent = ""
foreach ($tag in $tags) {
    $vms = Get-VM -Tag $tag
    $inventoryContent += "[$tag]`n"
    foreach ($vm in $vms) {
        $vmName = $vm.Name
        $inventoryContent += "$vmName ansible_connection=$vmName`n"
    }
    $inventoryContent += "`n"
}

$outputFilePath = "C:\temp\hosts"
Set-Content -Path $outputFilePath -Value $inventoryContent




### End Result ###
<#
[dev]
server01 ansible_connection=server01
server02 ansible_connection=server02

[test]
server22 ansible_connection=server22
server33 ansible_connection=server33

#>