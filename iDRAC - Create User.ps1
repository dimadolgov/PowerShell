<#
.Synopsis
   iDRAC cmdlet using Redfish API to either create or delete iDRAC user
.DESCRIPTION
   iDRAC cmdlet using Redfish API to either create or delete iDRAC user
   PARAMETERS 
   - idrac_ip: Pass in iDRAC IP address
   - idrac_username: Pass in iDRAC username
   - idrac_password: Pass in iDRAC username password
   - idrac_user_id: Pass in the user account ID you want to configure
   - idrac_new_username: Pass in the new user name you want to create
   - idrac_new_password: Pass in the new password you want to set for the new user
   - idrac_user_privilege: Pass in the privilege level for the user you are creating. Supported values are: Administrator, Operator, ReadOnly and None. Note: these values are case sensitive
   - idrac_user_enable: Enable of disable the new iDRAC user you are creating. Pass in 'true' to enable the user, pass in 'false' to disable the user
   - get_idrac_user_accounts: Get current settings for all iDRAC user accounts, pass in 'y'. If you want to get only a specific user account, also pass in argument 'idrac_user_id'
   - delete_idrac_user: Delete iDRAC user, pass in the user account id
.EXAMPLE
   Invoke-CreateIdracUserPasswordREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -get_idrac_user_accounts y
   This example shows getting all iDRAC user account information
.EXAMPLE
   Invoke-CreateIdracUserPasswordREDFISH -idrac_ip 192.168.0.120 -get_idrac_user_accounts y -idrac_user_id 3
   This example will first prompt for iDRAC username/password using Get-Credential, then return only information for iDRAC user account 3
.EXAMPLE
   Invoke-CreateIdracUserPasswordREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -idrac_user_id 3 -idrac_new_username user3 -idrac_new_password test123 -idrac_user_privilege ReadOnly -idrac_user_enable true
   This example shows creating iDRAC user for account ID 3 with Read Only privileges and enabling the account
.EXAMPLE
   Invoke-CreateIdracUserPasswordREDFISH -idrac_ip 192.168.0.120 -idrac_user_id 3 -idrac_user_privilege ReadOnly -idrac_user_enable true
   This example will first prompt for iDRAC username/password using Get-Credential, then prompt to pass in new username and password using Get-Credential for the new user you're creating which is account ID 3. This new user will be created with Read Only privileges and enabled
.EXAMPLE
   Invoke-CreateIdracUserPasswordREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -delete_idrac_user 3
   This example shows deleting iDRAC user account 3
#>

function Invoke-CreateIdracUserPasswordREDFISH {


    param(
        [Parameter(Mandatory=$True)]
        [string]$idrac_ip,
        [Parameter(Mandatory=$False)]
        [string]$idrac_username,
        [Parameter(Mandatory=$False)]
        [string]$idrac_password,
        [Parameter(Mandatory=$False)]
        [string]$x_auth_token,
        [Parameter(Mandatory=$False)]
        [int]$idrac_user_id,
        [Parameter(Mandatory=$False)]
        [string]$idrac_new_username,
        [Parameter(Mandatory=$False)]
        [string]$idrac_new_password,
        [Parameter(Mandatory=$False)]
        [string]$idrac_user_privilege,
        [Parameter(Mandatory=$False)]
        [string]$idrac_user_enable,
        [Parameter(Mandatory=$False)]
        [string]$get_idrac_user_accounts,
        [Parameter(Mandatory=$False)]
        [string]$delete_idrac_user
        )
    
    # Function to ignore SSL certs
    
    function Ignore-SSLCertificates
{
        $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
        $Compiler = $Provider.CreateCompiler()
        $Params = New-Object System.CodeDom.Compiler.CompilerParameters
        $Params.GenerateExecutable = $false
        $Params.GenerateInMemory = $true
        $Params.IncludeDebugInformation = $false
        $Params.ReferencedAssemblies.Add("System.DLL") > $null
        $TASource=@'
            namespace Local.ToolkitExtensions.Net.CertificatePolicy
            {
                public class TrustAll : System.Net.ICertificatePolicy
                {
                    public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                    {
                        return true;
                    }
                }
            }
    '@ 
        $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
        $TAAssembly=$TAResults.CompiledAssembly
        $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
        [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
    }
    
    $global:get_powershell_version = $null
    
    function get_powershell_version 
    {
    $get_host_info = Get-Host
    $major_number = $get_host_info.Version.Major
    $global:get_powershell_version = $major_number
    }
    get_powershell_version
    
    
    function setup_idrac_creds
    {
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
    
    if ($x_auth_token)
    {
    $global:x_auth_token = $x_auth_token
    }
    elseif ($idrac_username -and $idrac_password)
    {
    $user = $idrac_username
    $pass= $idrac_password
    $secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
    $global:credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)
    }
    else
    {
    $get_creds = Get-Credential
    $global:credential = New-Object System.Management.Automation.PSCredential($get_creds.UserName, $get_creds.Password)
    }
    }
    
    setup_idrac_creds
    
    
    if ($get_idrac_user_accounts -and $idrac_user_id)
    {
    Write-Host "`n- INFO, executing GET command to get iDRAC user account $idrac_user_id information"
    
    $uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$idrac_user_id" [$idrac_ip]
    if ($x_auth_token)
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    
    else
    {
        try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    $result.Content | ConvertFrom-Json
    return
    }
    
    
    if ($get_idrac_user_accounts)
    {
    Write-Host "`n- INFO, executing GET command to get iDRAC user account information`n"
    $count_range = 2..16
    foreach ($i in $count_range)
    {
    $uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$i" [$idrac_ip]
    if ($x_auth_token)
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    
    else
    {
        try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    $result.Content | ConvertFrom-Json
    }
    return
    }
    
    
    if ($idrac_new_username -and $idrac_user_privilege -and $idrac_user_enable)
    {
    
    if ($idrac_user_enable -eq "true")
    {
    $enable_status = $true
    }
    if ($idrac_user_enable -eq "false")
    {
    $enable_status = $false
    }
    
    if ($idrac_new_password)
    {
    $JsonBody = @{UserName = $idrac_new_username; Password= $idrac_new_password; RoleId = $idrac_user_privilege; Enabled = $enable_status} | ConvertTo-Json -Compress
    }
    else
    {
    $get_new_user_password = Get-Credential -UserName $idrac_new_username -Message "Create password for new user $idrac_new_username"
    $get_new_user_password = $get_new_user_password.GetNetworkCredential().Password
    $JsonBody = @{"UserName" = $idrac_new_username; "Password" = $get_new_user_password; "RoleId" = $idrac_user_privilege; "Enabled" = $enable_status} | ConvertTo-Json -Compress
    }
    
    $uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$idrac_user_id" [$idrac_ip]
    
    if ($x_auth_token)
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        
        $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
        }
        else
        {
        Ignore-SSLCertificates
        $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
        }
        }
        catch
        {
        Write-Host
        $RespErr
        return
        } 
    }
    
    
    else
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        
        $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
        }
        else
        {
        Ignore-SSLCertificates
        $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
        }
        }
        catch
        {
        Write-Host
        $RespErr
        return
        } 
    }
    
    
    if ($result1.StatusCode -eq 200)
    {
        [String]::Format("`n- PASS, statuscode {0} returned successfully for PATCH command to create iDRAC user {1}",$result1.StatusCode, $idrac_new_username)
    }
    else
    {
        [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
        return
    }
    
    $uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$idrac_user_id" [$idrac_ip]
    if ($x_auth_token)
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    
    else
    {
        try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    
    if ($result.StatusCode -ne 200)
    {
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
    }
    
    $check_username = $result.Content | ConvertFrom-Json
    if ($check_username.UserName -eq $idrac_new_username)
    {
    Write-Host "- PASS, iDRAC user '$idrac_new_username' successfully created`n"
    }
    
    else
    {
    Write-Host "- FAIL, iDRAC user $idrac_new_username not successfully created"
    return
    }
    return
    
    }
    
    
    if ($delete_idrac_user)
    {
    Write-Host "`n- INFO, deleting iDRAC user account $delete_idrac_user"
    $JsonBody = @{Enabled = $false; RoleId = "None"} | ConvertTo-Json
    
    $uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$delete_idrac_user" [$idrac_ip]
    if ($x_auth_token)
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        
        $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
        }
        else
        {
        Ignore-SSLCertificates
        $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
        }
        }
        catch
        {
        Write-Host
        $RespErr
        return
        } 
    }
    
    
    else
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        
        $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
        }
        else
        {
        Ignore-SSLCertificates
        $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
        }
        }
        catch
        {
        Write-Host
        $RespErr
        return
        } 
    }
    
    $JsonBody = @{UserName = ""} | ConvertTo-Json -Compress
    
    $uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$delete_idrac_user" [$idrac_ip]
    
    if ($x_auth_token)
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        
        $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
        }
        else
        {
        Ignore-SSLCertificates
        $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token} -ErrorVariable RespErr
        }
        }
        catch
        {
        Write-Host
        $RespErr
        return
        } 
    }
    
    
    else
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        
        $result1 = Invoke-WebRequest -UseBasicParsing -SkipHeaderValidation -SkipCertificateCheck -Uri $uri -Credential $credential -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
        }
        else
        {
        Ignore-SSLCertificates
        $result1 = Invoke-WebRequest -UseBasicParsing -Uri $uri -Credential $credential -Method Patch -Body $JsonBody -ContentType 'application/json' -Headers @{"Accept"="application/json"} -ErrorVariable RespErr
        }
        }
        catch
        {
        Write-Host
        $RespErr
        return
        } 
    }
    
    if ($result1.StatusCode -eq 200)
    {
        [String]::Format("`n- PASS, statuscode {0} returned successfully for PATCH command to delete iDRAC user {1}",$result1.StatusCode, $delete_idrac_user)
    }
    else
    {
        [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
        return
    }
    
    $uri = "https://$idrac_ip/redfish/v1/Managers/iDRAC.Embedded.1/Accounts/$delete_idrac_user" [$idrac_ip]
    if ($x_auth_token)
    {
    try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept" = "application/json"; "X-Auth-Token" = $x_auth_token}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"; "X-Auth-Token" = $x_auth_token}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    
    else
    {
        try
        {
        if ($global:get_powershell_version -gt 5)
        {
        $result = Invoke-WebRequest -SkipCertificateCheck -SkipHeaderValidation -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        else
        {
        Ignore-SSLCertificates
        $result = Invoke-WebRequest -Uri $uri -Credential $credential -Method Get -UseBasicParsing -ErrorVariable RespErr -Headers @{"Accept"="application/json"}
        }
        }
        catch
        {
        $RespErr
        return
        }
    }
    
    if ($result.StatusCode -ne 200)
    {
    [String]::Format("`n- FAIL, statuscode {0} returned",$result.StatusCode)
    return
    }
    
    $check_username = $result.Content | ConvertFrom-Json
    if ($check_username.UserName -eq "")
    {
    Write-Host "- PASS, iDRAC user id '$delete_idrac_user' successfully deleted`n"
    }
    
    else
    {
    Write-Host "- FAIL, iDRAC user $delete_idrac_user not successfully deleted"
    return
    }
    return
}

}


        $iDrac_IPs = Get-Content -Path C:\Temp\idrac.txt
        
        $new_user = "XXXX"
        $new_password = "XXXX"
        $User = "XXXX"
        $Pass = "XXXX"
        
        foreach ($iDrac_IP in $iDrac_IPs)
            {
                Write-Host "Working on $iDrac_IP" -ForegroundColor Cyan 
                #Create new iDRAC user xxxxx
                #Invoke-CreateIdracUserPasswordREDFISH -idrac_ip $iDrac_IP -idrac_username "root" -idrac_password "" -idrac_user_id 5 -idrac_new_username $new_user -idrac_new_password $new_password -idrac_user_privilege Administrator -idrac_user_enable true
                #Remove root user
                $root_id = Invoke-CreateIdracUserPasswordREDFISH -idrac_ip $iDrac_IP -get_idrac_user_accounts y -idrac_username $new_user -idrac_password $new_password | Where-Object UserName -Like "root"
                #Invoke-CreateIdracUserPasswordREDFISH -idrac_ip $iDrac_IP -idrac_username $new_user -idrac_password $new_password -delete_idrac_user $root_id.Id
                #Change root user to Read Only privilege
                Invoke-CreateIdracUserPasswordREDFISH -idrac_ip $iDrac_IP -idrac_username $new_user -idrac_password $new_password -idrac_user_id $root_id.id -idrac_new_username $User -idrac_new_password $Pass -idrac_user_privilege ReadOnly -idrac_user_enable true 
            }