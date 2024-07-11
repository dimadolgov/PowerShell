#1  Changes Mod to SYNCHRONOUS
#2  Split Parent Storage Group
#3  Set TAG on Removed Pired Volumes
#4  Delete Pair (MUST be in SYNCHRONOUS MODE )
#5  Create Snapshot on Storage Group
#6  Remove Masking View on Source
#7  Create Masking View on Destination

#### STEP 2 ####

#8  Create SDRF Pair, Automatically creates Volumes on Destination
#9  Create Parent Storage Group 
#10 Adds Volumes to Child Storage Group
#11 Add Child to Parent
#12 Start SRDF Replication

#Connect to Unisphere
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$unisphere = Connect-Unisphere -HostName 'unisphere-ip' -Port 8443 

#Add Prefix
Import-Module -Prefix powermax dell.powermax

#Array IDs

$array = Get-PowerMaxArray $unisphere # Get All Arrays
$PowerMax_Destination = '000000000000' #New PowerMAX Destination
$vMAX_Source = '000000000000' #Old vMAX Source
$vMAX_Destination = '000000000000' #Old vMAX Destination

############################### STEP 1 - Enter Parameters ###############################

#Enter Storage Group Parameter (Server you want to migrate)
$SG_Parent = 'SG_h_c27-rs510-boot'
$Source_Storage = $vMAX_Source
$Destination_Storage = $PowerMax_Destination
$Destination_Port_Group = 'PG_h_MaorT'
$RDF_GroupNumber = '91'

#Change Mod to SYNCHRONOUS
SetMode-powermaxRDFProtection -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent -RDFGroup $RDF_GroupNumber -Mode SYNCHRONOUS

#Split Parent Storage Group
Split-powermaxRDFProtection -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent -RDFGroup $RDF_GroupNumber -Immediate:$true -Verbose

#Set TAG on Removed Pired Volumes
$Destination_Pair_Volume = (Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RDF_GroupNumber -StorageGroupId $SG_Parent -ErrorAction Ignore).RemoteVolumeName
    foreach ($Identifier in $Destination_Pair_Volume)
    {
        Set-powermaxVolume -Unisphere $unisphere -ArrayId $Destination_Storage  -Id $Identifier -Identifier 'migrated' -Force -Verbose
    }

#Delete Pair (MUST be in SYNCHRONOUS MODE )
$Source_Pair_Volume = (Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RDF_GroupNumber -StorageGroupId $SG_Parent).LocalVolumeName
    foreach ($PAIR in $Source_Pair_Volume)
    {
        Remove-powermaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RDF_GroupNumber -VolumeId $PAIR -Force -Confirm:$false  -Verbose
    }

#Create Snapshot on Storage Group
New-powermaxStorageGroupSnapshot -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent -SnapshotId ('Snapshot_'+$SG_Parent) -Verbose

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
Remove-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View -Force -Verbose

#Create Masking View on Destination
New-powermaxMaskingView -Unisphere $unisphere -ArrayId $Destination_Storage -Id "$Masking_View" -StorageGroupId $SG_Parent -PortGroupId $Destination_Port_Group -HostId $HostId -Verbose


############################### STEP 2 - Enter New Source and Destination Parameters ###############################

$Source_Storage = $PowerMax_Destination
$Destination_Storage = $vMAX_Destination
$Destination_SRP = 'SRP'
$SRDF_Group = '111'

#Get Initiator Group from Masking View (source)
$Masking_View_Source = (Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent).Maskingview
$Initiator_Group_Source = (Get-powermaxMaskingView -Unisphere $unisphere -ArrayId $Source_Storage -Id $Masking_View_Source).HostId
$Host_Initiators_Source = (Get-powermaxHost -Unisphere $unisphere -ArrayId $Source_Storage -Id $Initiator_Group_Source).Initiator

#Get Initiator Group WWN from Current Storage
$Source_Host = (Get-PowerMaxHost -Unisphere $unisphere -ArrayId $Source_Storage -Id $Initiator_Group_Source).Initiator

#Get Storage Group Parent and Child from Source
$Source_Storage_Group = Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent
$Source_Storage_Group_Child = $Source_Storage_Group.ChildStorageGroup
$SLO = (Get-PowerMaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $Source_Storage_Group_Child).slo

#Get Volume ID from Source
$Source_Volumes = Get-PowerMaxVolume -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Parent

#Create SDRF Pair, And automatically creates Volumes on Destination
foreach ($Source_Volume in $Source_Volumes.id)
    {
        New-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $SRDF_Group -VolumeId $Source_Volume -Mode ADAPTIVECOPYDISK -Type RDF1 -InvalidateR2 $true -Verbose -ErrorAction Stop
    }

#Get Remote Volume from paired source storage
$RemoteVolumeName =  (Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $SRDF_Group -StorageGroupId $SG_Parent).RemoteVolumeName 

#Create Parent Storage Group 
New-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage -Id $SG_Parent -Verbose -ErrorAction Stop

#Get and Create Child Storage Group
$SG_Child =  (Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage -Id $SG_Parent).ChildStorageGroup
New-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage -Id "$SG_Child" -SRP $Destination_SRP -SLO $SLO -NoCompression:$false -Verbose -ErrorAction Stop

#Adds Volumes to Child Storage Group
foreach ($Volume in $RemoteVolumeName)
    {
        Set-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage "$SG_Child" -AddVolumeId $Volume -SrdfForce:$true -ErrorAction Stop
    }

#Add Child to Parent
Set-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Destination_Storage -Id $SG_Parent -AddStorageGroupId $SG_Child -Verbose  -ErrorAction Stop

#Start SRDF Replication
Establish-powermaxRDFProtection -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $SRDF_Group -StorageGroupId $SG_Parent -ErrorAction Stop

