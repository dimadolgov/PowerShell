
#Create Storage Group Parent 
#Create Storage Group Child
#Add All Childs to Parent
#Create Volumes on Destination Inside Child Storage Groups (same size)
#Create new Host (Initiator Group)
#Create Masking View
#Add Snapshot Policy (Policy: DailyDefault)


#Connect to Unisphere
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$unisphere = Connect-Unisphere -HostName 'unisphere-ip' -Port 8443 

#Add Prefix
Import-Module -Prefix powermax dell.powermax

#Array IDs
$array = Get-PowerMaxArray $unisphere # Get All PowerMax Arrays
$SRC = 'pmax_number' #PowerMAX_SOURCE
$DST = 'pmax_number' #PowerMAX_DESTINATION

#Paremeters
$SG_Parent = 'SG_parent'
$Source_Storage = $SRC
$Destination_Storage = $DST
$Destination_SRP = (Get-powermaxSrp -Unisphere $unisphere -ArrayId $Destination_Storage).Id
    
#Get Initiator Group from Masking View Source
$Masking_View_Source = (Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent).Maskingview
$Initiator_Group_Source = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View_Source).HostId
$Host_Initiators_Source = (Get-powermaxHost -Unisphere $unisphere -ArrayId $Source_Storage -Id $Initiator_Group_Source).Initiator
$PortGroupId = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View_Source).PortGroupId

#Get Storage Group Parent and Child from Source
$Source_Storage_Group = Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent | select *
$Source_Storage_Group_Child = $Source_Storage_Group.ChildStorageGroup

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

#Create Volumes on Destination Inside Child Storage Groups
$Source_Storage_Group = Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent
$Source_Storage_Group_Child = $Source_Storage_Group.ChildStorageGroup
$Volumes = foreach ($volume in $Source_Storage_Group_Child)
    {
        Get-powermaxVolume -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId  $volume
    }
$Volume_Capacities =  $Volumes.CapMb
$StorageGroupIDs = $Volumes.StorageGroupId
for ($i = 0; $i -lt $Volume_Capacities.Count; $i++) 
    {
        $Volume_Capacity = $Volume_Capacities[$i]
        $StorageGroupID = $StorageGroupIDs[$i]
        New-PowerMaxVolume -Unisphere $unisphere -ArrayId $Destination_Storage -StorageGroupId $StorageGroupID -Size $Volume_Capacity -Unit MB
    }

#Get HostId From Destination
$Masking_View = (Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent).Maskingview
$HostData = Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View
if ($null -eq $HostData.HostGroupId)
    {
        $HostId = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View).HostId
    }
    else 
        {
            $HostId = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View).HostGroupId
        }

#Create new Host (Initiator Group)
New-powermaxHost -Unisphere $unisphere -ArrayId $Destination_Storage -Id $Initiator_Group_Source -InitiatorId $Host_Initiators_Source

#Create Masking View
New-powermaxMaskingView -Unisphere $unisphere -ArrayId $Destination_Storage -Id "$Masking_View" -StorageGroupId $SG_Parent -PortGroupId $PortGroupId -HostId $HostId

#Add Snapshot Policy (Policy: DailyDefault)
Set-powermaxSnapshotPolicy -Unisphere $unisphere -ArrayId $Destination_Storage -AddStorageGroupId  $SG_Parent -Id "DailyDefault"
