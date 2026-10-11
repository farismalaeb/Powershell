<#
Version history:
REQUIRED Automation Account resources (this runbook will fail with a named error if any are missing):
  Variables   : 
  - AAtenant: Your Entra ID tenant ID
  - AppReg_AppID: Application (client) ID of the runbook's app registration
  - AppMonSenderMailbox: Mailbox the emails are sent from
  - AppMonFallbackEmail: Receives reports for apps with no owner
  - AppReg_DaysThreshold: How many days ahead to look; expired credentials are always included
  - App_Reg_IncludeAdmin: Admins who receive the full tenant report, comma separated
  The application authenticate to Graph using Certificate, not ClientSecret
  
REQUIRED modules imported into this Automation Account (Shared Resources > Modules):
  Microsoft.Graph.Authentication
  Microsoft.Graph.Applications
  Microsoft.Graph.Users.Actions   (for Send-MgUserMail)
Note: #Requires -Modules is NOT honored by Azure Automation's runbook execution — modules must
be imported into the Automation Account itself, not just referenced in the script.

REQUIRED Graph API permissions on the app registration (read-only; no write scopes needed):
  Application.Read.All
  Mail.Send
#>
try{
    [int]$DaysThreshold = Get-AutomationVariable -Name 'AppReg_DaysThreshold' -ErrorAction Stop
}
catch{
        throw "[ERR]::Automation Variable 'AppReg_DaysThreshold' not found or inaccessible: $($_.Exception.Message)"
}

try{
     [string[]]$IncludeAdmin = Get-AutomationVariable -Name 'App_Reg_IncludeAdmin' -ErrorAction Stop
}
catch{
        throw "[ERR]::Automation Variable 'App_Reg_IncludeAdmin' not found or inaccessible: $($_.Exception.Message)"
}

Write-Output "Version 1.6"
Write-Output "[INFO]:: Starting"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

#### Azure Automation configuration (Certificate Authentication) ####
# Each lookup is wrapped individually so a missing Variable/Certificate in this
# Automation Account fails with a clear, named error instead of an opaque
# "unhandled exception" at the job level.
try {
    $tenant = Get-AutomationVariable -Name 'AAtenant' -ErrorAction Stop
}
catch {
    throw "[ERR]::Automation Variable 'AAtenant' not found or inaccessible: $($_.Exception.Message)"
}

try {
    $Client_Id = Get-AutomationVariable -Name 'AppReg_AppID' -ErrorAction Stop
}
catch {
    throw "[ERR]::Automation Variable 'AppReg_AppID' not found or inaccessible: $($_.Exception.Message)"
}

$CertificateName = "AppMonCert"
try {
    $certObj = Get-AutomationCertificate -Name $CertificateName -ErrorAction Stop
    if (-not $certObj) { throw "Get-AutomationCertificate returned nothing for '$CertificateName'" }
    $cert = $certObj.Thumbprint
}
catch {
    throw "[ERR]::Automation Certificate '$CertificateName' not found or inaccessible: $($_.Exception.Message)"
}

# SenderMailbox / FallbackEmail: pull from Automation Variables if present,
# otherwise fall back to the values hardcoded in the old runbook.
try {
    $SenderMailbox = Get-AutomationVariable -Name 'AppMonSenderMailbox' -ErrorAction Stop
}
catch {
    throw "[WARN]::Automation Variable 'AppMonSenderMailbox' not found."
}

try {
    $FallbackEmail = Get-AutomationVariable -Name 'AppMonFallbackEmail' -ErrorAction Stop
}
catch {
    throw "[WARN]::Automation Variable 'AppMonFallbackEmail' not found."
}

Write-Output "[INFO]:: Configuration Load is complete"

# Connect to Microsoft Graph using Certificate Authentication
try {
    Connect-MgGraph -ClientId $Client_Id -TenantId $tenant -CertificateThumbprint $cert -NoWelcome -ErrorAction Stop
    Write-Output "[INFO]:: Connected using Certificate authentication"
}
catch {
    throw "Error connecting to Microsoft Graph: $($_.Exception.Message)"
}



$expirationLimit = (Get-Date).AddDays($DaysThreshold)

# Retrieve all App Registrations that have secrets or certificates
try {
    $servicePrincipals = Get-MgApplication -All -ErrorAction Stop | Where-Object {($_.PasswordCredentials -notlike $null) -or ($_.KeyCredentials -notlike $null)}
}
catch {
    throw "[ERR]::Failed to retrieve App Registrations: $($_.Exception.Message)"

    }
Write-Output "[INFO]:: Number of Apps matching is : $($servicePrincipals.count)"

# Prepare report with owner information
$fullresults = @()

foreach ($sp in $servicePrincipals) {
    Write-Output "[INFO]::Parsing $($sp.DisplayName)"

    # Get app owners
    $appOwners = @()
    try {
        $owners = Get-MgApplicationOwner -ApplicationId $sp.Id
        foreach ($owner in $owners | where {$_.AdditionalProperties.'@odata.type' -notlike '*.servicePrincipal*'}) {
            if ($owner.AdditionalProperties.mail) {
                $appOwners += $owner.AdditionalProperties.mail
            }
            Else {
                Write-Warning "Unable to read the Mail value for $($owner.id) of type $($owner.AdditionalProperties.'@odata.type')" 
            }
        }
    }
    catch {
        Write-Error "[WARN]::Unable to get owners for $($sp.DisplayName): $($_.Exception.Message)"
    }

    # If no owners found, use the fallback email
    if ($appOwners.Count -eq 0) {
        $appOwners += $FallbackEmail
    }

    $secrets = $sp.PasswordCredentials
    $CertKey = $sp.KeyCredentials

    foreach ($secret in $secrets) {
        if ($secret.EndDateTime -lt $expirationLimit) {
            $Singleresults = [PSCustomObject]@{
                AppName         = $sp.DisplayName
                AppId           = $sp.AppId
                Secretname      = $secret.DisplayName
                SecretExpiry    = $secret.EndDateTime
                CredentialType  = "Secret"
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
                CredentialType  = "Certificate"
                Secret          = $false
                Certificate     = $true
                DaysUntilExpiry = if (($singlecer.EndDateTime - (Get-Date)).Days -lt 1) { "Already Expired" } else { ($singlecer.EndDateTime - (Get-Date)).Days }
                Owners          = $appOwners
            }
            $fullresults += $Singleresults
        }
    }
}

### Enterprise Applications: SAML SSO signing certificates
# SAML signing certificates live on the service principal, not on the app registration.
Write-Output "%%%%%%%%%%%%%%%%%   [INFO]:: Checking Enterprise Applications with SAML SSO   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
try {
    $samlApps = Get-MgServicePrincipal -All -Property Id, AppId, DisplayName, PreferredSingleSignOnMode, PreferredTokenSigningKeyThumbprint, KeyCredentials, NotificationEmailAddresses -ErrorAction Stop |
        Where-Object { $_.PreferredSingleSignOnMode -eq 'saml' -and $_.KeyCredentials }
}
catch {
    Write-Error "[WARN]::Failed to retrieve Enterprise Applications (SAML check skipped): $($_.Exception.Message)"
    $samlApps = @()
}
Write-Output "[INFO]:: Number of SAML Enterprise Apps is : $($samlApps.count)"

foreach ($samlApp in $samlApps) {
    Write-Output "[INFO]::Parsing Enterprise App $($samlApp.DisplayName)"

    # Each SAML certificate is stored twice (Sign and Verify), so keep the Sign entry only.
    # If an active certificate is set, report only that one, so old inactive certificates don't create noise.
    $signingCerts = $samlApp.KeyCredentials | Where-Object { $_.Usage -eq 'Sign' }
    if ($samlApp.PreferredTokenSigningKeyThumbprint) {
        $activeCert = $signingCerts | Where-Object {
            $_.CustomKeyIdentifier -and ([System.BitConverter]::ToString($_.CustomKeyIdentifier) -replace '-', '') -eq $samlApp.PreferredTokenSigningKeyThumbprint
        }
        if ($activeCert) { $signingCerts = $activeCert }
    }

    $expiringCerts = $signingCerts | Where-Object { $_.EndDateTime -lt $expirationLimit }
    if (-not $expiringCerts) { continue }

    # Get Enterprise App owners (only when there is something to report)
    $samlOwners = @()
    try {
        $owners = Get-MgServicePrincipalOwner -ServicePrincipalId $samlApp.Id
        foreach ($owner in $owners ) {
            if ($owner.AdditionalProperties.mail) {
                $samlOwners += $owner.AdditionalProperties.mail
            }
            else {
                Write-Warning "Unable to read the Mail value for $($owner.id), UPN: $($owner.AdditionalProperties.userPrincipalName), Object Type: $($owner.AdditionalProperties.'@odata.type')" 

            }
        }
    }
    catch {
        Write-Warning "[WARN]::Unable to get owners for $($samlApp.DisplayName): $($_.Exception.Message)"
    }

    # No owners? Use the SAML certificate notification emails, then the fallback email
    if ($samlOwners.Count -eq 0 -and $samlApp.NotificationEmailAddresses) {
        $samlOwners += $samlApp.NotificationEmailAddresses
    }
    if ($samlOwners.Count -eq 0) {
        $samlOwners += $FallbackEmail
    }
    $samlOwners = $samlOwners | Select-Object -Unique

    foreach ($samlCert in $expiringCerts) {
        $Singleresults = [PSCustomObject]@{
            AppName         = $samlApp.DisplayName
            AppId           = $samlApp.AppId
            Secretname      = if ($samlCert.DisplayName) { $samlCert.DisplayName } else { "SAML Signing Certificate" }
            SecretExpiry    = $samlCert.EndDateTime
            CredentialType  = "SAML SSO Certificate"
            Secret          = $false
            Certificate     = $true
            DaysUntilExpiry = if (($samlCert.EndDateTime - (Get-Date)).Days -lt 1) { "Already Expired" } else { ($samlCert.EndDateTime - (Get-Date)).Days }
            Owners          = $samlOwners
        }
        $fullresults += $Singleresults
    }
}

### Send individual emails to each owner

if ($fullresults.Count -gt 0) {
    Write-Output "[INFO]::Results Found: $($fullresults.Count)"

    # Shared email style for owner and admin reports
    $reportStyle = @"
<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    h2 { color: #d9534f; border-bottom: 2px solid #d9534f; padding-bottom: 10px; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th { background-color: #FFFF99; color: black; padding: 12px 8px; border: 1px solid black; text-align: left; font-weight: bold; }
    td { padding: 10px 8px; border: 1px solid black; vertical-align: top; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .expired { background-color: #f2dede !important; color: #a94442; font-weight: bold; }
    .warning { background-color: #fcf8e3 !important; color: #8a6d3b; }
</style>
"@


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
        $ownerResultsHtml = $reportStyle + @"
<h2>⚠️ Application Credentials Expiry Report</h2>
<p><strong>Dear $owner,</strong></p>
<p>The following applications that you own (app registrations and Enterprise Application SAML SSO certificates) have credentials expiring within the next $DaysThreshold days. Please review and renew them as necessary to avoid service disruptions.</p>
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
            $credentialType = $entry.CredentialType
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
                            Address = $owner
                        }
                    }
                )
            }
        }

        try {
            Send-MgUserMail -UserId $SenderMailbox -BodyParameter $params -ErrorAction Stop
            Write-Output "[EMAIL]::Email sent successfully to $owner"
        }
        catch {
            Write-Error "[ERR]::Failed to send email to $owner - $($_.Exception.Message)"
        }
    }

    ### Send the full report to the admin(s), if requested
    if ($IncludeAdmin) {
        # Support both an array and a comma separated string (useful with Task Scheduler / Automation schedule params)
        $adminList = $IncludeAdmin -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique
        Write-Output "[EMAIL]::Preparing full admin report for $($adminList -join ', ')"

        $expiredCount  = ($fullresults | Where-Object { $_.DaysUntilExpiry -eq "Already Expired" }).Count
        $noOwnerCount  = ($fullresults | Where-Object { ($_.Owners -join ',') -eq $FallbackEmail }).Count

        $adminHtml = $reportStyle + @"
<h2>⚠️ Full Application Credentials Expiry Report (Admin)</h2>
<p><strong>Hello Admin,</strong></p>
<p>This is the full list of app registration secrets, certificates, and Enterprise Application SAML SSO certificates in the tenant that expired or will expire within the next $DaysThreshold days.</p>
<p><strong>Total:</strong> $($fullresults.Count) &nbsp;|&nbsp; <strong>Already expired:</strong> $expiredCount &nbsp;|&nbsp; <strong>No owner:</strong> $noOwnerCount</p>
<table>
    <tr>
        <th>Application Name</th>
        <th>App ID</th>
        <th>Credential Type</th>
        <th>Secret/Cert Name</th>
        <th>Expiry Date</th>
        <th>Days Until Expiry</th>
        <th>Owner(s) Notified</th>
    </tr>
"@

        # Sort by expiry date, so expired and most urgent items are at the top
        foreach ($entry in ($fullresults | Sort-Object SecretExpiry)) {
            $rowClass = if ($entry.DaysUntilExpiry -eq "Already Expired") { "expired" } elseif ([int]$entry.DaysUntilExpiry -le 7) { "warning" } else { "" }
            $ownerText = if (($entry.Owners -join ',') -eq $FallbackEmail) { "No owner (sent to $FallbackEmail)" } else { $entry.Owners -join '<br>' }

            $adminHtml += @"
    <tr class="$rowClass">
        <td>$($entry.AppName)</td>
        <td>$($entry.AppId)</td>
        <td>$($entry.CredentialType)</td>
        <td>$($entry.Secretname)</td>
        <td>$($entry.SecretExpiry)</td>
        <td>$($entry.DaysUntilExpiry)</td>
        <td>$ownerText</td>
    </tr>
"@
        }

        $adminHtml += @"
</table>
<br>
<p><em>Each owner listed above received a separate email with their own applications only.</em></p>
<hr>
<p><small>Report generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</small></p>
"@

        $adminParams = @{
            Message = @{
                Subject = "Admin Report: Application Credentials Expiring Soon - $(Get-Date -Format 'yyyy-MM-dd')"
                Body = @{
                    ContentType = "HTML"
                    Content = $adminHtml
                }
                ToRecipients = @($adminList | ForEach-Object { @{ EmailAddress = @{ Address = $_ } } })
            }
        }

        try {
            Send-MgUserMail -UserId $SenderMailbox -BodyParameter $adminParams -ErrorAction Stop
            Write-Output "[EMAIL]::Admin report sent successfully to $($adminList -join ', ')"
        }
        catch {
            Write-Error "[ERR]::Failed to send admin report - $($_.Exception.Message)"
        }
    }

    Write-Output "[INFO]::Email reports sent to all owners"
} else {
    Write-Output "[INFO]:: No action required, no expiring credentials found"
}

Disconnect-MgGraph | Out-Null
Write-Output "[INFO]:: END"
