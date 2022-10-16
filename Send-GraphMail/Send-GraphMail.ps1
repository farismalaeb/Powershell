
<#PSScriptInfo

.VERSION 1.2.4

.GUID 5027146b-5a2b-498f-b873-e5f268f149ad

.AUTHOR Faris Malaeb

.COMPANYNAME PowerShellCenter.com

.COPYRIGHT 2022

.TAGS Send-GraphMail,Mail, Graph API, Send-MgUserMail

.LICENSEURI 

.PROJECTURI https://www.powershellcenter.com/2022/09/07/powershell-script-to-simplify-send-mgusermail/

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

.SYNOPSIS
   Send Microsoft Graph Email messaging using a simplified approach
.DESCRIPTION
    Send Microsoft Graph Email messaging using a simplified approach and similar to Send-MailMessage. Also support a multiple parameters and support multiple attachment. Also it support sending from Microsoft Personal account
.NOTES
    This script is no longer a function. you can use direct, no need to import it to the PowerShell workspace
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.PARAMETER
    Send-GraphMail Support the following parameters
    [Array] To: The recipients address, it can be an array for multiple account, just make sure to include the array type @("User1@domain.com","User2@Domain.com")
    [Array] Bcc: Similar to To, but this is the BCC and also support array of recipients
    [Array] CC: Similar to To and Bcc, also support array of recipients.
    [String] Subject: The Message Subject
    [String] MessageFormat: it can be HTML or Text
    [String] Body: The Message Body you want to send.
    [Switch] BodyFromFile: This is a Switch parameter. Using it mean that the body is stored in a file in your harddrive. When using the BodyFromFile, the Body parameter should be the full path of the file.
    [Switch] DeliveryReport: Set to receive a delivery report email or not
    [Switch] ReadReport: set to receive a read report or not.
    [Switch] Flag: enable the follow-up flag for the message
    [ValicationSet] Importance: Set the message priority, it can be one of the following, Low or High
    [String] Attachments: The Attachment file path. For now it only support 1 attachment, if you want more, let me know
    [String] DocumentType: The attachment MIME type, for example for text file, the DocumentType is text/plain
    [Switch] ReturnJSON: This wont send the email, but instead it return the JSON file fully structured and ready so you can invoke it with any other tool.
    [HashTable] MultiAttachment: Use this parameter to send more than one attachment, this parameter is a Hashtable as the following @{"Attachment Path No.1"="DocumentType";"Attachment Path No.2"="DocumentType"}. You cannot use the MultiAttachment with Attachments parameter
    [Switch] GraphDebug: Return the debug log for the process
    ##############
    NOT included, Beta endpoins are not included, such as Mentions.

.EXAMPLE
Send Graph email message to multiple users with attachments and multiple To, CC and single Bcc
Send-GraphMail -To @('user1@domain.com','user2@domain.com') -CC @('cc@domain.com','cc1@domain.com) -Bcc "bcc@domain.com" -Subject "Test Message" -MessageFormat HTML -Body 'This is the Message Body' -DeliveryReport -ReadReport -Flag -Importance High -Attachments C:\MyFile.txt -DocumentType 'text/plain'

Send Graph email, load the Body from a file stored locally, make sure to use the BodyFromFile switch
send-GraphMail -To 'user1@domain.com' -Subject "Test Message" -MessageFormat HTML -Body C:\11111.csv -BodyFromFile -DeliveryReport -ReadReport -Flag -Importance High -Attachments 'C:\MyFile.txt' -DocumentType 'text/plain'

Return and get how the JSON is structured without sending the Email, this is done by using the -ReturnJSON Parameter
$JSONFile=Send-GraphMail -To 'user1@domain.com' -Subject "Test Message" -MessageFormat HTML -Body "Hi This is New Message" -Flag -ReturnJSON

Send Graph email including multiple attachment.
Send-GraphMail -To "ToUser@powershellcenter.com" -CC "farisnt@gmail.com" -Bcc "CCUser@powershellcenter.com" -Subject "Test V1" -MessageFormat HTML -Body "Test" -MultiAttachment @{"C:\11111.csv"="text/plain";"C:\222222.csv"="text/plain"}

#> 

    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]$To,
        [Parameter(Mandatory=$false)]$CC,
        [Parameter(Mandatory=$false)]$Bcc,
        [Parameter(Mandatory=$false)]$Subject,
        [Parameter(Mandatory=$false)]
        [ValidateSet('HTML','Text')]$MessageFormat,
        [Parameter(Mandatory=$false,ParameterSetName='Body')]
        [parameter(ParameterSetName='Attach')]
        [parameter(ParameterSetName='Attachmore')]
        $Body,
        [Parameter(Mandatory=$false,ParameterSetName='Body')]
        [parameter(ParameterSetName='Attach')]
        [parameter(ParameterSetName='Attachmore')]
        [Switch]$BodyFromFile,
        [Parameter(Mandatory=$false)][switch]$DeliveryReport,
        [Parameter(Mandatory=$false)][switch]$ReadReport,
        [Parameter(Mandatory=$false)][switch]$Flag,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Low','High')] $Importance,
        [Parameter(Mandatory=$false,ParameterSetName='Attach')]$Attachments,
        [Parameter(Mandatory=$True,ParameterSetName='Attach')]$DocumentType,
        [Parameter(Mandatory=$false)][switch]$ReturnJSON,
        [Parameter(Mandatory=$false)][switch]$GraphDebug,
        [Parameter(Mandatory=$True,ParameterSetName='Attachmore')][Hashtable]$MultiAttachment

    )

$Body=[ordered]@{} 
$Body.Message=@{}

## Body Subject Parameter
switch ($PSBoundParameters.ContainsKey('Subject')) {
    $true { $Body.Message.Add('Subject',$Subject) }
    $false {}
}
## DeliveryReport
switch ($PSBoundParameters.ContainsKey('DeliveryReport')) {
    $true { $Body.Message.Add('isDeliveryReceiptRequested',"True") }
    $false {}
}

## Flag
switch ($PSBoundParameters.ContainsKey('Flag')) {
    $true { $Body.Message.Add('flag',@{flagStatus="flagged"}) }
    $false {}
}


## Read Report
switch ($PSBoundParameters.ContainsKey('ReadReport')) {
    $true { $Body.Message.Add('isReadReceiptRequested',"True") }
    $false {}
}
## $Importance
switch ($PSBoundParameters.ContainsKey('Importance')) {
    $true { $Body.Message.Add('Importance',$Importance) }
    $false {}
}

## Body Parameter
switch ($PSBoundParameters.ContainsKey('Body')) {
    $true { 
        $Body.Message.Add('Body',@{})
        $Body.Message.Body.Add('ContentType',$PSBoundParameters['MessageFormat'])
        if ($PSBoundParameters.ContainsKey('BodyFromFile')){
            try{
           $MessageBody = Get-Content -Path ($PSBoundParameters['Body']) -Raw -ErrorAction stop
           $Body.Message.Body.Add('Content',$MessageBody)
            }
            catch{
                write-host "Cannot Attach Body, The error is " -ForegroundColor Yellow
                Throw $_.Exception
            }
        }
        Else{
            $Body.Message.Body.Add('Content',$PSBoundParameters['Body'])
        }
}
    $false {}
}

## Attachment Parameter
switch ($PSBoundParameters.ContainsKey('Attachments')) {
    $true { $Body.Message.Add('Attachments',@()) 
            Foreach ($Singleattach In $Attachments){ 
                $AttachDetails=@{}
                $AttachDetails.Add("@odata.type", "#microsoft.graph.fileAttachment")
                $AttachDetails.Add('Name',$Singleattach)
                $AttachDetails.Add('ContentType',$DocumentType)
                $AttachDetails.Add('ContentBytes',[Convert]::ToBase64String([IO.File]::ReadAllBytes($Singleattach)))
                $Body.message.Attachments+=$AttachDetails
            }

    }
    $false {}
}

## MultiAttachment
switch ($PSBoundParameters.ContainsKey('MultiAttachment')) {
    $true { $Body.Message.Add('Attachments',@()) 
            Foreach ($SingleattachinMulti In $MultiAttachment.GetEnumerator()){ 
                $AttachmultiDetails=@{}
                $AttachmultiDetails.Add("@odata.type", "#microsoft.graph.fileAttachment")
                $AttachmultiDetails.Add('Name',$SingleattachinMulti.Name)
                $AttachmultiDetails.Add('ContentType',$SingleattachinMulti.Key)
                $AttachmultiDetails.Add('ContentBytes',[Convert]::ToBase64String([IO.File]::ReadAllBytes($SingleattachinMulti.Name)))
                $Body.message.Attachments+=$AttachmultiDetails
            }

    }
    $false {}
}

## No Recp is selected, the fail
if ((!($PSBoundParameters.ContainsKey('To'))) -and (!($PSBoundParameters.ContainsKey('Bcc'))) -and (!($PSBoundParameters.ContainsKey('Bcc'))) ){
    Throw "You need to use one Address parameter To or CC or BCC"
}
## To Parameter
switch ($PSBoundParameters.ContainsKey('To')) {
    $true { $Body.Message.Add('ToRecipients',@()) 
            Foreach ($SingleToAddress In $To){
                $Body.message.ToRecipients+=@{EmailAddress=@{Address=$SingleToAddress}}
            }

    }
    $false {}
}

## CC Parameter
switch ($PSBoundParameters.ContainsKey('cc')) {
    $true { $Body.Message.Add('CcRecipients',@()) 
            Foreach ($SingleCCAddress In $cc){
                $Body.message.CcRecipients+=@{EmailAddress=@{Address=$SingleCCAddress}}
            }
    }
    $false {}
}

## Bcc Parameter
switch ($PSBoundParameters.ContainsKey('Bcc')) {
    $true { $Body.Message.Add('BccRecipients',@()) 
            Foreach ($SingleBCCAddress In $Bcc){
                $Body.message.BccRecipients+=@{EmailAddress=@{Address=$SingleBCCAddress}}
            }
    }
    $false {}
}

switch ($PSBoundParameters.ContainsKey('ReturnStructure')) {
    $true { return  $Body  }
    $false {}
}

switch ($PSBoundParameters.ContainsKey('ReturnJSON')) {
    $true { return  ($Body | ConvertTo-Json -Depth 100)  }
    $false {
        try{
        Import-module Microsoft.Graph.Authentication
        Connect-MgGraph -Scopes @('Mail.Send')
        }
        Catch{
            $_.Exception.Message
        }
    }
}



    switch ($PSBoundParameters.ContainsKey('GraphDebug')) {
        $true  { Invoke-GraphRequest -Uri 'https://graph.microsoft.com/v1.0/me/sendMail' -Method POST -Body $Body -Debug }
        $false { Invoke-GraphRequest -Uri 'https://graph.microsoft.com/v1.0/me/sendMail' -Method POST -Body $Body  }
    }
 


