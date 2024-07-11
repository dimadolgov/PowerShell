#1  Set Mod to Synchronous
#2  Split Parent Storage Group
#3  Set TAG on Removed Paired Volumes
#4  Delete SRDF Pair
#5  Create Snapshot on Source Storage Group
#6  Remove Masking View on Source
#7  Create Masking View on Destination

#Connect to Unisphere
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$unisphere = Connect-Unisphere -HostName 'unisphere-ip' -Port 8443 

#Add Prefix
Import-Module -Prefix powermax dell.powermax

#Array IDs
$PowerMAX_Destination = '000000000000' #PowerMAX_Destination
$vMAX_Source = '000000000000' #vMAX_Source

#Enter Storage Group Parameter (Server you want to migrate)
$SG_Parent = 'SG_'
$Source_Storage = $vMAX_Source
$Destination_Storage = $PowerMAX_Destination
$Destination_Port_Group = 'PG_'
$RDF_GroupNumber = '00'

#Set Mod to Synchronous
SetMode-powermaxRDFProtection -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent -RDFGroup $RDF_GroupNumber -Mode SYNCHRONOUS

#Split Parent Storage Group
Split-powermaxRDFProtection -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent -RDFGroup $RDF_GroupNumber -Immediate:$true

#Set TAG on Removed Pired Volumes
$Destination_Pair_Volume = (Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RDF_GroupNumber -StorageGroupId $SG_Parent -ErrorAction Ignore).RemoteVolumeName
    foreach ($Identifier in $Destination_Pair_Volume)
    {
        Set-powermaxVolume -Unisphere $unisphere -ArrayId $Destination_Storage  -Id $Identifier -Identifier 'migrated' -Force
    }

#Delete Pair (MUST be in SYNCHRONOUS MODE )
$Source_Pair_Volume = (Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RDF_GroupNumber -StorageGroupId $SG_Parent).LocalVolumeName
    foreach ($PAIR in $Source_Pair_Volume)
    {
        Remove-powermaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RDF_GroupNumber -VolumeId $PAIR -Force -Confirm:$false  -Verbose
    } 

#Create Snapshot on Storage Group
New-powermaxStorageGroupSnapshot -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent -SnapshotId ('Snapshot_'+$SG_Parent)

#Get HostId From Destination
$Masking_View = (Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent).Maskingview
$HostData = Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View
if ($HostData.HostGroupId -eq $null)
    {
        $HostId = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View).HostId
    }
    else 
        {
            $HostId = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View).HostGroupId
        }

#Remove Masking View on Source
Remove-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View -Force

#Create Masking View on Destination
New-powermaxMaskingView -Unisphere $unisphere -ArrayId $Destination_Storage -Id "$Masking_View" -StorageGroupId $SG_Parent -PortGroupId $Destination_Port_Group -HostId $HostId