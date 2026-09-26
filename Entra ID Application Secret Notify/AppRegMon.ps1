[CmdletBinding(DefaultParameterSetName = 'Secret')]
param (
    [Parameter(Mandatory=$false)][string]$TenantId='979feaee-b9cb-4b5d-b3c3-5a11ee95b809',
    [Parameter(Mandatory=$false)][string]$ClientId,
    [Parameter(Mandatory=$false, ParameterSetName = 'Certificate')][string]$CertificateThumbprint,
    [Parameter(Mandatory=$false, ParameterSetName = 'Secret')][securestring]$ClientSecret,
    [Parameter(Mandatory=$false)][string]$SenderMailbox='admin@powershellcode.com',
    [Parameter(Mandatory=$false)][string]$FallbackEmail='admin@powershellcode.com',
    [int]$DaysThreshold = 30,
    [string[]]$IncludeAdmin
)

Write-Output "Version 1.5"
Write-Output "[INFO]:: Starting"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# Connect to Microsoft Graph using the selected authentication method
try {
    if ($PSCmdlet.ParameterSetName -eq 'Secret') {
        $cred = [pscredential]::new($ClientId, $ClientSecret)
        Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $cred -NoWelcome -ErrorAction Stop
    }
    else {
        Connect-MgGraph -ClientId $ClientId -TenantId $TenantId -CertificateThumbprint $CertificateThumbprint -NoWelcome -ErrorAction Stop
    }
    Write-Output "[INFO]:: Connected using $($PSCmdlet.ParameterSetName) authentication"
}
catch {
    Write-Error "Error connecting to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

$expirationLimit = (Get-Date).AddDays($DaysThreshold)

# Retrieve all App Registrations that have secrets or certificates
$servicePrincipals = Get-MgApplication -All | Where-Object {($_.PasswordCredentials -notlike $null) -or ($_.KeyCredentials -notlike $null)}
Write-Output "[INFO]:: Number of Apps matching is : $($servicePrincipals.count)"

# Prepare report with owner information
$fullresults = @()

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
Write-Output "[INFO]:: Checking Enterprise Applications with SAML SSO"
$samlApps = Get-MgServicePrincipal -All -Property Id, AppId, DisplayName, PreferredSingleSignOnMode, PreferredTokenSigningKeyThumbprint, KeyCredentials, NotificationEmailAddresses |
    Where-Object { $_.PreferredSingleSignOnMode -eq 'saml' -and $_.KeyCredentials }
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
        foreach ($owner in $($owners | Where-Object {$_.AdditionalProperties.userPrincipalName -notlike "*_*"})) {
            if ($owner.AdditionalProperties.mail) {
                $samlOwners += $owner.AdditionalProperties.mail
            }
        }
    }
    catch {
        Write-Output "[WARN]::Unable to get owners for $($samlApp.DisplayName): $($_.Exception.Message)"
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
        # Support both an array and a comma separated string (useful with Task Scheduler)
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