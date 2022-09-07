<#
.SYNOPSIS
   Send Microsoft Graph Email messaging using a simplified approach
.DESCRIPTION
    Send Microsoft Graph Email messaging using a simplified approach with support to a multiple parameters 
.NOTES
    This Script wont authenticate to Graph API, make sure to use Connect-MgGraph first
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
    ##############
    NOT included, Beta endpoins are not included, such as Mentions.

.EXAMPLE
Send Graph email message to multiple users with attachments and multiple To, CC and single Bcc
Send-GraphMail -To @('user1@domain.com','user2@domain.com') -CC @('cc@domain.com','cc1@domain.com) -Bcc "bcc@domain.com" -Subject "Test Message" -MessageFormat HTML -Body 'This is the Message Body' -DeliveryReport -ReadReport -Flag -Importance High -Attachments C:\MyFile.txt -DocumentType 'text/plain'

Send Graph email, load the Body from a file stored locally, make sure to use the BodyFromFile switch
send-GraphMail -To 'vdi1@adcci.gov.ae' -Subject "Test Message" -MessageFormat HTML -Body C:\11111.csv -BodyFromFile -DeliveryReport -ReadReport -Flag -Importance High -Attachments 'C:\MyFile.txt' -DocumentType 'text/plain'

Return and get how the JSON is structured without sending the Email, this is done by using the -ReturnJSON Parameter
$JSONFile=send-GraphMail -To 'vdi1@adcci.gov.ae' -Subject "Test Message" -MessageFormat HTML -Body "Hi This is New Message" -Flag -ReturnJSON

#> 
Function Send-GraphMail {
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
        $Body,
        [Parameter(Mandatory=$false,ParameterSetName='Body')]
        [parameter(ParameterSetName='Attach')]
        [Switch]$BodyFromFile,
        [Parameter(Mandatory=$false)][switch]$DeliveryReport,
        [Parameter(Mandatory=$false)][switch]$ReadReport,
        [Parameter(Mandatory=$false)][switch]$Flag,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Low','High')] $Importance,
        [Parameter(Mandatory=$false,ParameterSetName='Attach')]$Attachments,
        [Parameter(Mandatory=$false)][switch]$ReturnJSON,
        [Parameter(Mandatory=$True,ParameterSetName='Attach')]$DocumentType

    )

 $Body=[ordered]@{} 
$Body.Message=@{}

## Body Subject Parameter
switch ($PSBoundParameters.ContainsKey('Subject')) {
    $true { $Body.Message.Add('Subject',"MySubject") }
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
            Foreach ($Singleattach In $Attachments){ #OKay as you are reading here, This should fixed to support multiple attachment, Each attach should have its own ContentType.
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
    $false {}
}


if ((!(Get-MgContext)) -and (!($PSBoundParameters.ContainsKey('ReturnJSON'))))
    {Throw "Please connect to Graph first"}
Send-mgUsermail -UserId (Get-MgContext).Account -BodyParameter $Body -Debug 

}

