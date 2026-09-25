Write-Output "[INFO]:: Starting"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12


$tenant = TENANT_ID_GOES_HERE
$CertificateName = "AppMonCert"
$cert = (Get-AutomationCertificate -Name $CertificateName).Thumbprint
$Client_Id = Get-AutomationVariable -Name 'AppReg_AppID'
#$Scope = "https://graph.microsoft.com/.default"
Write-Output "[INFO]:: Configuration Load is complete"

  
try {
    Connect-MgGraph -ClientId $Client_Id -TenantId $tenant -CertificateThumbprint $cert -ErrorAction Stop
}
catch {
    Write-Error "Error connecting to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

$daysThreshold = 30
$expirationLimit = (Get-Date).AddDays($daysThreshold)

# Retrieve all Service Principals (since App secrets are stored there)
$servicePrincipals = Get-MgApplication -All | Where-Object {($_.PasswordCredentials -notlike $null) -or ($_.KeyCredentials -notlike $null)} #| select AppId, DisplayName, PasswordCredentials,KeyCredentials
Write-Output "[INFO]:: Number of Apps matching is : $($servicePrincipals.count)"

# Prepare report with owner information
$fullresults= @()

foreach ($sp in $servicePrincipals) {
    Write-Output "[INFO]::Parsing $($sp.DisplayName)"
    
    # Get app owners
    $appOwners = @()
    try {
        $owners = Get-MgApplicationOwner -ApplicationId $sp.Id
        foreach ($owner in $($owners | Where-Object {$_.AdditionalProperties.userPrincipalName -notlike "*_*"})) {
            if ($owner.AdditionalProperties.mail) {
                $appOwners += $owner.AdditionalProperties.mail
            }
        }
    }
    catch {
        Write-Output "[WARN]::Unable to get owners for $($sp.DisplayName): $($_.Exception.Message)"
    }
    
    # If no owners found, use a default/fallback email
    if ($appOwners.Count -eq 0) {
        $appOwners += "admin@contoso.com"  # Replace with your fallback email
    }
    
    $secrets = $sp.PasswordCredentials  # Get stored secrets
    $CertKey= $sp.KeyCredentials

    foreach ($secret in $secrets) {
        if ($secret.EndDateTime -lt $expirationLimit) {
            $Singleresults = [PSCustomObject]@{
                AppName         = $sp.DisplayName
                AppId           = $sp.AppId
                Secretname      = $secret.DisplayName
                SecretExpiry    = $secret.EndDateTime
                Secret          = $true
                Certificate     = $false
                DaysUntilExpiry = if (($secret.EndDateTime - (Get-Date)).Days -lt 1) { "Already Expired" } else { ($secret.EndDateTime - (Get-Date)).Days }
                Owners          = $appOwners
            }
            $fullresults += $Singleresults
        }
    }

    foreach ($singlecer in $CertKey) {
        if ($singlecer.EndDateTime -lt $expirationLimit) {
            $Singleresults = [PSCustomObject]@{
                AppName         = $sp.DisplayName
                AppId           = $sp.AppId
                Secretname      = "Certificate"
                SecretExpiry    = $singlecer.EndDateTime
                Secret          = $false
                Certificate     = $true
                DaysUntilExpiry = if (($singlecer.EndDateTime - (Get-Date)).Days -lt 1) { "Already Expired" } else { ($singlecer.EndDateTime - (Get-Date)).Days }
                Owners          = $appOwners
            }
            $fullresults += $Singleresults
        }
    }
}

### Send individual emails to each owner

if ($fullresults.Count -gt 0) {
    Write-Output "[INFO]::Results Found: $($fullresults.Count)"
    
    # Group results by owner
    $ownerGroups = @{}
    
    foreach ($result in $fullresults) {
        foreach ($owner in $result.Owners) {
            if (-not $ownerGroups.ContainsKey($owner)) {
                $ownerGroups[$owner] = @()
            }
            $ownerGroups[$owner] += $result
        }
    }
    
    Write-Output "[EMAIL]::Sending reports to $($ownerGroups.Count) owner(s)"
    
    # Send email to each owner
    foreach ($owner in $ownerGroups.Keys) {
        $ownerResults = $ownerGroups[$owner]
        
        Write-Output "[INFO]::Preparing report for $owner with $($ownerResults.Count) item(s)"
        
        # Create HTML table for this owner's applications
        $ownerResultsHtml = @"
<style>
    body {
        font-family: Arial, sans-serif;
        margin: 20px;
    }
    h2 {
        color: #d9534f;
        border-bottom: 2px solid #d9534f;
        padding-bottom: 10px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin-top: 20px;
    }
    th {
        background-color: #FFFF99;
        color: black;
        padding: 12px 8px;
        border: 1px solid black;
        text-align: left;
        font-weight: bold;
    }
    td {
        padding: 10px 8px;
        border: 1px solid black;
        vertical-align: top;
    }
    tr:nth-child(even) {
        background-color: #f9f9f9;
    }
    .expired {
        background-color: #f2dede !important;
        color: #a94442;
        font-weight: bold;
    }
    .warning {
        background-color: #fcf8e3 !important;
        color: #8a6d3b;
    }
</style>
<h2>⚠️ Application Credentials Expiry Report</h2>
<p><strong>Dear $owner,</strong></p>
<p>The following application registrations that you own have credentials (secrets or certificates) expiring within the next 30 days. Please review and renew them as necessary to avoid service disruptions.</p>
<table>
    <tr>
        <th>Application Name</th>
        <th>App ID</th>
        <th>Credential Type</th>
        <th>Secret/Cert Name</th>
        <th>Expiry Date</th>
        <th>Days Until Expiry</th>
    </tr>
"@

        # Add rows for this owner
        foreach ($entry in $ownerResults) {
            $credentialType = if ($entry.Secret) { "Secret" } else { "Certificate" }
            $rowClass = if ($entry.DaysUntilExpiry -eq "Already Expired") { "expired" } elseif ([int]$entry.DaysUntilExpiry -le 7) { "warning" } else { "" }
            
            $ownerResultsHtml += @"
    <tr class="$rowClass">
        <td>$($entry.AppName)</td>
        <td>$($entry.AppId)</td>
        <td>$credentialType</td>
        <td>$($entry.Secretname)</td>
        <td>$($entry.SecretExpiry)</td>
        <td>$($entry.DaysUntilExpiry)</td>
    </tr>
"@
        }

        $ownerResultsHtml += @"
</table>
<br>
<p><strong>Action Required:</strong></p>
<ul>
    <li>Review each application and renew expiring credentials</li>
    <li>Update applications with new credentials before expiry</li>
    <li>Test applications after credential renewal</li>
</ul>
<p><em>This is an automated report. For questions, please contact your IT administrator.</em></p>
<hr>
<p><small>Report generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</small></p>
"@

        # Send email to this owner
        $params = @{
            Message = @{
                Subject = "Action Required: Your Application Credentials Expiring Soon - $(Get-Date -Format 'yyyy-MM-dd') $($owner)"
                Body = @{
                    ContentType = "HTML"
                    Content = $ownerResultsHtml
                }
                ToRecipients = @(
                    @{
                        EmailAddress = @{
                            Address = $($owner) ####$owner $($owner)
                        }
                    }
                )
             
            }
        }

        try {
            Send-MgUserMail -UserId 'mailfrom@domain.com' -BodyParameter $params
            Write-Output "[EMAIL]::Email sent successfully to $owner"
        }
        catch {
            Write-Error "[ERR]::Failed to send email to $owner - $($_.Exception.Message)"
        }
    }
    
    Write-Output "[INFO]::Email reports sent to all owners"
} else {
    Write-Output "[INFO]:: No action required, no expiring credentials found"
}

Write-Output "[INFO]:: END"
