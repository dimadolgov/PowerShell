# Connect to vRA and get token (Header)
$Cred = (Get-Credential) # (username@net.iec.co.il)
$token = Connect-vRAServer -Server 'vra-server-ip' -Credential $Cred -IgnoreCertRequirements        
$refreshToken = $token.RefreshToken
$refreshToken = @{'refreshToken' = $refreshToken}
$JSON_Token = $refreshToken | ConvertTo-Json
$token = Invoke-RestMethod -Method Post -Uri 'https://vra-server-ip/iaas/api/login [vra-server-ip]' -Headers @{'Content-Type'='application/json'} -Body $JSON_Token
$headers = @{'Content-Type'='application/json'
                    'Authorization' = 'Bearer ' + $token.token}
$Url = '/iaas/api/machines?$top=100000'
$content = (Invoke-vraRestMethod -Method get -Uri $Url).content

# Connect to VC and get Powered On VMs with Tag "TEST"
    Connect-VIServer -Server 'vc-server-ip' -Credential $Cred -WarningAction SilentlyContinue | Out-Null
    $VMs = Get-VM | Get-TagAssignment | Where-Object { $_.Tag.Name -eq "TEST" -and $_.Tag.Category.Name -eq "Environment" } 
    $PoweredOnVMs = $VMs.Entity | where-Object {$_.PowerState -like "PoweredOn"}

# Change Lease Time 
    $counter = 0
        foreach ($ExpiredVM in $PoweredOnVMs.name)
            {
                # Get All VMs Deployment Information
                $counter++
                Write-Progress -Id 0 -Activity 'Checking servers' -Status "Processing $($counter) of $($PoweredOnVMs.count)" -CurrentOperation $ExpiredVM -PercentComplete (($counter/$PoweredOnVMs.Count) * 100)
                Write-Host $ExpiredVM
                    # $90Days = (get-date).AddDays(90).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") ### add 90 days to current expiration date
                    $New_Lease_Date = '2030-01-01T12:00:00Z'
                    $Url = '/iaas/api/machines?$top=100000'
                    $TargetVM = $content | Where-Object {$_.name -eq $ExpiredVM}
                    # $vm = Get-vRADeployment -Id $TargetVM.deploymentId # Get Deployment ID

                # Create Payload and convert to JSON 
                    $jsonPayload = @{
                        actionId = "Deployment.ChangeLease"
                        inputs = @{
                            "Lease Expiration Date" = $New_Lease_Date
                        }
                    }
                    $json = $jsonPayload | ConvertTo-Json

                # Send an API request to update the VM lease
                    Invoke-RestMethod -Uri "https://vra-server-ip/deployment/api/deployments/$($TargetVM.deploymentId)/requests" [vra-server-ip] -Method Post -Body $json -Headers $headers
            }
