$Cred = (Get-Credential) # (username@domain.com)
$token = Connect-vRAServer -Server 'vra-server-ip' -Credential $Cred -IgnoreCertRequirements        
$refreshToken = $token.RefreshToken
$refreshToken = @{'refreshToken' = $refreshToken}
$JSON_Token = $refreshToken | ConvertTo-Json
$token = Invoke-RestMethod -Method Post -Uri 'https://vra-server-ip/iaas/api/login [vra-server-ip]' -Headers @{'Content-Type'='application/json'} -Body $JSON_Token
$headers = @{'Content-Type'='application/json'
                    'Authorization' = 'Bearer ' + $token.token}

# Get VMs Content
    $Url = '/iaas/api/machines?$top=100000' 
    $content = (Invoke-vraRestMethod -Method get -Uri $Url).content 

# Change Deployment name to VM Hostname
    foreach ($vm in $content)
        {
            Write-Host $vm.name
            $newDeploymentName = $vm.name
            $updateDeploymentEndpoint = "https://vra-server-ip [vra-server-ip] /deployment/api/deployments/$($vm.deploymentId)"
            $JSON = @{'name' = $newDeploymentName} | ConvertTo-Json
            Invoke-RestMethod -Uri $updateDeploymentEndpoint -Method Patch -Headers $headers -Body $JSON
        }
