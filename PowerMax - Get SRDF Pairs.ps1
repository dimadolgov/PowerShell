[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    $unisphere = Connect-Unisphere -HostName 'unisphere-ip' -Port 8443 
    
#Add Prefix
    Import-Module -Prefix powermax dell.powermax

#Array IDs
    $array = Get-PowerMaxArray $unisphere
    $PowerMAX = '000000000000' #PowerMAX
    $Source_Storage = $PowerMAX

$SGs = Get-powermaxStorageGroup -Unisphere $unisphere -ArrayId $Source_Storage | select *
$Groups = $SGs | Where-Object { ($_.ChildStorageGroup -NE $null)} #-and ($_.NumOfMaskingViews -ge 1) }


    foreach ($SG_Child in $Groups.ChildStorageGroup)
    {
  Write-Host $SG_Child (Get-Date).TimeOfDay
    $RdfGroupNumbers = (Get-powermaxStorageGroupRDFGroup  -Unisphere $unisphere -ArrayId $Source_Storage -StorageGroupId $SG_Child).RdfGroupNumber

        if($RdfGroupNumbers.count -ge 1)
            {
                foreach ($RdfGroupNumber in $RdfGroupNumbers)
                        {
                            $Source_Pair_Volume = (Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RdfGroupNumber -StorageGroupId $SG_Child).LocalVolumeName 
                            $Destination_Pair_Volume = (Get-PowerMaxRDFPair -Unisphere $unisphere -ArrayId $Source_Storage -RDFGroup $RdfGroupNumber -StorageGroupId $SG_Child).RemoteVolumeName
    
                            $all = for ($i = 0; $i -lt $Source_Pair_Volume.Count; $i++)
                                {
                                    "{0} {1}" -f $Source_Pair_Volume[$i],$Destination_Pair_Volume[$i]
                                }
    
                            $all >> C:\temp\SRDF_Pairs\$SG_Child'_'$RdfGroupNumber.txt
                        }
            }
        
    }

