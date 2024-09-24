Import-Module PowerFGT | Out-Null

########## Set Credentials
$Cred = Get-Credential 

# Define the firewalls with aliases
$firewalls = @{
    "1" = @{ Name = "Canada.domain.local"; Alias = "Canada" }
    "2" = @{ Name = "Denmark.domain.local"; Alias = "Denmark" }
    "3" = @{ Name = "Holland.domain.local"; Alias = "Holland" }
    "4" = @{ Name = "Thailand.domain.local"; Alias = "Thailand" }
    "5" = @{ Name = "Austria.domain.local"; Alias = "Austria" }
}

########## Firewall selection loop
$validSelection = $false

while (-not $validSelection) {
    Write-Host "Select a Firewall"
    
    # Display available firewalls by their index and alias
    foreach ($key in ($firewalls.Keys | Sort-Object)) {
        Write-Host "$key) $($firewalls[$key].Alias)"
    }
    
    # Get user input for the numeric selection
    $firewallSelection = Read-Host "Enter the number of the firewall you'd like to select"
    
    # Validate if the selection is a valid index in the $firewalls hashtable
    if ($firewalls.ContainsKey($firewallSelection)) {
        $validSelection = $true
    }
    else {
        Write-Host "Invalid selection. Please enter a valid number."
    }
}

# Retrieve the selected firewall based on the numeric selection
$selectedFirewall = $firewalls[$firewallSelection]

# Confirm the selected firewall
Write-Host "You selected: $($selectedFirewall.Name) $($selectedFirewall.Alias)"

########## Connect to selected firewall
Connect-FGT -Server $selectedFirewall.Name -port 8443 -SkipCertificateCheck -Credentials $Cred | Out-Null

# Get the VPN IPsec tunnels and select the name
$vpnTunnels = Get-FGTMonitorVpnIPsec | Select-Object -ExpandProperty name | sort-object
$counter = 1
$vpnTunnels | ForEach-Object {
    Write-Output ("{0}. {1}" -f $counter, $_)
    $counter++
}
$validSelection = $false
while (-not $validSelection) {
    $selection = Read-Host "Enter the number of the tunnel you'd like to select"
    $selection = [int]$selection
    if ($selection -le $vpnTunnels.Count -and $selection -gt 0) {
        $validSelection = $true
    }
    else {
        Write-Output "Invalid selection. Please enter a number between 1 and $($vpnTunnels.Count)."
    }
}
$ipsecTunnel = $vpnTunnels[$selection - 1]
Write-Output "You selected: $ipsecTunnel"

########## Create PS Commands
$down = "Get-FGTSystemInterface $ipsecTunnel | Set-FGTSystemInterface -status down"
$up = "Get-FGTSystemInterface $ipsecTunnel | Set-FGTSystemInterface -status up"

########## Confirmation
Write-Host "Reset"$ipsecTunnel.ToUpper()"on"$selectedFirewall.name.ToUpper()"?"
$confirm = Read-Host "Do you want to proceed? (Yes/No)"

########## Confirm action
if ($confirm -eq 'yes') {

    ########## Tunnel Down
    Invoke-Expression $down | Out-Null
    Write-Host "Tunnel: $ipsecTunnel "(Get-FGTSystemInterface $ipsecTunnel).status.ToUpper()"" -BackgroundColor Red 
    while ((Get-FGTSystemInterface $ipsecTunnel).status -eq "up") {
        Start-Sleep 1
        Write-Host "Bringing Tunnel Down"
    }
    Start-Sleep 10
    ########## Tunnel UP
    Invoke-Expression $up | Out-Null
    while ((Get-FGTSystemInterface $ipsecTunnel).status -eq "down") {
        Start-Sleep 1
        Write-Host "Bringing Tunnel Up"
    }
    Write-Host "Tunnel: $ipsecTunnel "(Get-FGTSystemInterface $ipsecTunnel).status.ToUpper()"" -BackgroundColor Green 
}
else {
    Write-Host "Action cancelled."
}

########## Disconnect from FW
Disconnect-FGT -Confirm:$false
