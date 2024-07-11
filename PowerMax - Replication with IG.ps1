#1  #Backup Source Masking View
#2  #Create SDRF Pair, Automatically creates Volumes on Destination
#3  #Export SRDF Pair to file
#4  #Create Parent Storage Group 
#5  #Adds Volumes to Child Storage Group
#6  #Add Child to Parent
#7  #Start SRDF Replication
#8  #Create new Host (IG)

#Connect to Unisphere
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$unisphere = Connect-Unisphere -HostName 'unisphere-ip' -Port 8443 
$linux_pass = Read-Host -Prompt "Enter Password"

#Add Prefix
Import-Module -Prefix powermax dell.powermax

#Array IDs
$array = Get-PowerMaxArray $unisphere
$PowerMAX_Destination = '000000000000' #PowerMAX_Destination
$vMAX_Source = '000000000000' #vMAX_Source

#Enter Storage Group Parameter (Server you want to migrate)
$SG_Parent = 'SG_parent'
$Source_Storage = $vMAX_Source
$Destination_Storage = $PowerMAX_Destination
$SRDF_Group = '00'
$Destination_SRP = 'SRP_1' #(Get-powermaxSrp -Unisphere $unisphere -ArrayId $Destination_Storage).Id

#Get Initiator Group from Masking View Source
$Masking_View_Source = (Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent).Maskingview
    if($null -eq (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View_Source).HostId)
        {   
            $HostGroupId = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View_Source).HostGroupId
        }
$HostId = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View_Source).HostId

Get-powermaxHostGroup  -Unisphere $unisphere -ArrayId $Source_Storage -Id $Initiator_Group_Source
$Host_Initiators_Source = (Get-powermaxHostGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $HostGroupId).Initiator

#Get Storage Group Parent and Child from Source
$Source_Storage_Group = Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent
$Source_Storage_Group_Child = $Source_Storage_Group.ChildStorageGroup
$SLOs = (Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $Source_Storage_Group_Child).slo

#Backup Masking View
echo yes | plink.exe -ssh linux-server -l "linux_user" -pw $linux_pass "sudo /usr/symcli/bin/symaccess -sid $Source_Storage show view $Masking_View_Source >> /home/MVs/$Masking_View_Source"

#Create SDRF Pair, Automatically creates Volumes on Destination (State will be Suspended)
$Source_Volumes = (Get-PowerMaxVolume -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent).Id
foreach ($Source_Volume in $Source_Volumes)
    {
        Write-Host "Creating SRDF Pair For $Source_Volume "
        New-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $SRDF_Group -VolumeId $Source_Volume -Mode ADAPTIVECOPYDISK -Type RDF1 -InvalidateR2 $true
    }

#Export SRDF Pairs to file
$PowerMaxRDFPair = Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $SRDF_Group -StorageGroupId $SG_Parent
$LocalVolumeName = $PowerMaxRDFPair.LocalVolumeName
$RemoteVolumeName = $PowerMaxRDFPair.RemoteVolumeName
$Pairs = for ($i = 0; $i -lt $LocalVolumeName.count; $i++)
    {
        if ($LocalVolumeName.count -ge 2)
            {
                "{0} {1}" -f $LocalVolumeName[$i],$RemoteVolumeName[$i]
            }
        else 
            {
            "{0} {1}" -f $LocalVolumeName,$RemoteVolumeName
            }
    }
$Dest_Storage = $Destination_Storage.Substring($Destination_Storage.Length -3,3)
echo $Pairs | plink.exe -ssh lxnpvm396 -l "linux-user" -pw $linux_pass "sudo cat  > /home/$SG_Parent'_'to_$Dest_Storage"

#Create Parent Storage Group 
New-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage -Id $SG_Parent

#Create Child Storage Groups
$SG_Childs =  (Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent).ChildStorageGroup
if ($SG_Childs.Count -eq 1)
    {
        $SLO = (Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Childs).slo
        New-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage -Id "$SG_Childs" -SRP $Destination_SRP -SLO $SLO -NoCompression:$false
    }

else {
    $SLOs = (Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Childs).slo
    for ($i = 0; $i -lt $SG_Childs.Count; $i++) 
            {
                $SG_Child = $SG_Childs[$i]
                $SLO = $SLOs[$i]
                New-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage -Id "$SG_Child" -SRP $Destination_SRP -SLO $SLO -NoCompression:$false
            }
        }

#Add All Childs (if available) to Parent
foreach ($SG_Child in $SG_Childs)
{
    Set-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage -Id $SG_Parent -AddStorageGroupId $SG_Child
}

#Adds Volumes to Child Storage Group - Need to add each volume to child !!!!!!!!!!
foreach ($Volume in $RemoteVolumeName)
{
    Set-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage $SG_Childs -AddVolumeId $Volume -SrdfForce:$true
}

#Start SRDF Replication
Establish-powermaxRDFProtection -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $SRDF_Group -StorageGroupId $SG_Parent

#Create new Host (Initiator Group)
New-powermaxHost -Unisphere $unisphere -ArrayId $Destination_Storage -Id $Initiator_Group_Source -InitiatorId $Host_Initiators_Source

#Show SRDF Replication Status
Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $SRDF_Group -StorageGroupId $SG_Parent | Format-Table

