param(
[parameter(mandatory)]$NumberofDay,
[parameter(Mandatory=$false)]
[ValidateNotNullOrEmpty()]$LDAPdistinguishedName
)

Function Send-PSCGraphEmail {
    param(
[parameter(Mandatory)]$To,
[parameter(Mandatory)]$subject,
[parameter(Mandatory)]$DaysToResetPassword,
[parameter(Mandatory)]
[ValidateSet('HTML','Text')]$MessageType
    )
$Name=(Get-mguser -userid $($PSBoundParameters['to'])).Displayname

$template = @"
<h2><span style="color: #008000;">Password Reset Notification</span></h2>
<p>Dear $((Get-Culture).TextInfo.ToTitleCase($Name))</p>
<p>Kindly note that your password will expire in $($PSBoundParameters['DaysToResetPassword']) days.</p>
<p>Please renew your password using <a href="https://www.office.com" target="_blank" rel="noopener"><em>Office 365</em></a> and click on <strong>Can&rsquo;t access your account</strong>?</p>
<p>Feel free to contact the ADCCI Helpdesk on 360 for additional information.</p>
<p>Regards,</p>
"@
$content = $template
 
$recipients = @()
$recipients += @{
    emailAddress = @{
        address = $PSBoundParameters['to']
    }
}
$message = @{
    subject = $PSBoundParameters['Subject'];
    toRecipients = $recipients;
    body = @{
        contentType = $PSBoundParameters['MessageType'];
        content = $content
    }
}
 
Send-MgUserMail -UserId (get-mguser -userid (Get-MgContext).account).mail -Message $message
}


Function Write-PSCLog{
    Param(
        $Message,
        [parameter(mandatory)]
        [ValidateSet("Critical","High","Normal","Low","Information")]
        $ErrorLevel
    )

    $logpath=(Join-Path $MyInvocation.PSScriptRoot -ChildPath "PasswordLog.txt")
    $ValuetoWrite=$PSBoundParameters['ErrorLevel'] +"  " + (Get-date).ToLongTimeString() +": " + $PSBoundParameters['Message']
    if (Test-Path $logpath){
        add-Content $logpath -Value $ValuetoWrite 
    }
    else{
        New-Item -Path $MyInvocation.PSScriptRoot -Name "PasswordLog.txt" -ItemType File -Value "$($ValuetoWrite)`n"
    }

}

Import-Module ActiveDirectory
Import-Module Microsoft.Graph.Teams


$Scope=@('Chat.Create','Chat.ReadWrite','Mail.Send','User.Read','User.Read.All') 
Connect-MgGraph -Scopes $Scope

$DaysToSendWarning = (get-date).adddays($PSBoundParameters['NumberofDay']).ToLongDateString()

#Find accounts that are enabled and have expiring passwords
switch ($PSBoundParameters.ContainsKey('LDAPdistinguishedName')) {
    $True { $users = Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False -and PasswordLastSet -gt 0 } `
    -Properties "Name", "EmailAddress", "msDS-UserPasswordExpiryTimeComputed","UserPrincipalName" -SearchBase $LDAPdistinguishedName | Select-Object -Property "Name", "UserPrincipalName","EmailAddress", `
    @{Name = "PasswordExpiry"; Expression = {[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed").tolongdatestring() }} }
    $false {$users = Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False -and PasswordLastSet -gt 0 } `
    -Properties "Name", "EmailAddress", "msDS-UserPasswordExpiryTimeComputed","UserPrincipalName" | Select-Object -Property "Name", "UserPrincipalName","EmailAddress", `
    @{Name = "PasswordExpiry"; Expression = {[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed").tolongdatestring() }}}
}


 #Find All ChatID with the recipient users
 $AllChatIDandUsers=@()
 $AllChat=get-mgchat -Filter "chattype eq 'oneOnOne'"
 Foreach ($SingleChat in $AllChat){
$ChatIDData=[PSCustomObject]@{
    ID = $SingleChat.Id
    UserID = (Get-MgChatMember -ChatId $SingleChat.Id )[1].DisplayName
    UserEmail=(Get-MgChatMember -ChatId $SingleChat.Id )[1].AdditionalProperties.email
}
$AllChatIDandUsers+=$ChatIDData
 }

foreach ($user in $users) {
try{
    $RecpID=Get-MgUser -UserId $user.UserPrincipalName -ErrorAction Stop
}
Catch{
write-host $_.Exception.Message
$ErrorMessage=$_.Exception.Message +", For user $($user.UserPrincipalName)"
Write-PSCLog -Message $ErrorMessage -ErrorLevel Critical
}

     if ($user.PasswordExpiry -eq $DaysToSendWarning) {
        $ChatSessionID=$AllChatIDandUsers |Where-Object {$_.useremail -like $user.EmailAddress}
        if (!($ChatSessionID)){
                $NewChatIDParam = @{
                    ChatType = "oneOnOne"
                    Members = @(
                        @{
                            "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                            Roles = @(
                                "owner"
                            )
                            "User@odata.bind" = "https://graph.microsoft.com/v1.0/users('"+(get-mguser -userid (Get-MgContext).account).id +"')"
                        }
                        @{
                            "@odata.type" = "#microsoft.graph.aadUserConversationMember"
                            Roles = @(
                                "owner"
                            )
                            "User@odata.bind" = "https://graph.microsoft.com/v1.0/users('"+$RecpID.id +"')"
                        }
                    )
                }
                $ChatSessionID=New-MgChat -BodyParameter $NewChatIDParam

        }
        Write-Host "Sending Message to $($RecpID.Mail)" -ForegroundColor Green
        try {
        New-MgChatMessage -ChatId $ChatSessionID.ID -Body @{Content ="Dear $($((Get-Culture).TextInfo.ToTitleCase($RecpID.GivenName))), Your Password will expire in $($PSBoundParameters['NumberofDay']) Days, Please follow the link to update it https://www.office.com"} -Importance Urgent 
        Send-PSCGraphEmail -To $RecpID.Mail -subject 'Password' -MessageType HTML -DaysToResetPassword $PSBoundParameters['NumberofDay'] 
        }
        catch{
            write-host $_.Exception.Message
            Write-PSCLog -Message $_.Exception.Message -ErrorLevel Critical

        }
 }

}
