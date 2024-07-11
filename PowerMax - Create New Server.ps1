#1  #Create StrageGroup and Volume
#2  #Add Child to Parent
#3  #Create Initiator Group
#4  #Create Masking View
#5  #Add Snapshot Policy (Policy: DailyDefault)

#Connect to Unisphere
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
$unisphere = Connect-Unisphere -HostName 'unisphere-ip' -Port 8443 

#Add Prefix
Import-Module -Prefix powermax dell.powermax

#Array IDs
$array = Get-PowerMaxArray $unisphere
$Current_Storage = 'powermax_number'

#Set New Storage Group Name \ Disk Count \ Disk Size \ Service Levels \ Initiators
$Global = 'saphhs'
$VolumesSizeGB = '150','10','70','20','20'
$PortGroup = 'PG_xxxx'
$Initiators = 'initiator_id1','initiator_id2','initiator_id3','initiator_id4'
$SLO = "optimized"
$SRP = "SRP_1"
$SymmetrixReplication = 'nor' # Choose: sra / srs / nor
            
#Variables
$SG_Parent = ('SG_'+$Global)
$SG_Child = ($SG_Parent+'_'+$SymmetrixReplication+'_sl'+ $SLO.Substring(0,1))
$InitiatorGroupName = ('IG_'+$Global)
$Masking_View = ('MV_'+$Global)
$SG_Parent,$SG_Child,$InitiatorGroupName,$Masking_View

#Create Strorage Group
New-StorageGroup -Unisphere $unisphere -ArrayId $Current_Storage -Id $SG_Parent -ErrorAction Stop

#Create Volume
New-StorageGroup -Unisphere $unisphere -ArrayId $Current_Storage -Id $SG_Child -SRP $SRP -SLO $SLO -NoCompression:$false -ErrorAction Stop
foreach ($Volume in $VolumesSizeGB)
    {
        New-PowerMaxVolume -Unisphere $unisphere -ArrayId $Current_Storage -StorageGroupId $SG_Child -Size $Volume -Unit GB -ErrorAction Stop
    }

#Add Child to Parent
Set-StorageGroup -Unisphere $unisphere -ArrayId $Current_Storage -Id $SG_Parent -AddStorageGroupId $SG_Child -Verbose -ErrorAction Stop

#Create Initiator Group
New-powermaxHost -Unisphere $unisphere -ArrayId $Current_Storage -Id $InitiatorGroupName -InitiatorId $Initiators -ErrorAction Stop

#Create Masking View
New-powermaxMaskingView -Unisphere $unisphere -ArrayId $Current_Storage -Id $Masking_View -StorageGroupId $SG_Parent -PortGroupId $PortGroup -HostId $InitiatorGroupName -ErrorAction Stop

#Add Snapshot Policy (Policy: DailyDefault)
Set-powermaxSnapshotPolicy -Unisphere $unisphere -ArrayId $Current_Storage -AddStorageGroupId  $SG_Parent -Id "DailyDefault" -ErrorAction Stop

