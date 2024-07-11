Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
$cred = Get-Credential
$vc = "vc"
Connect-VIServer -Server $vc -Credential $cred -WarningAction SilentlyContinue | Out-Null
Disconnect-VIServer -Server $vc -Confirm:$false -Force
