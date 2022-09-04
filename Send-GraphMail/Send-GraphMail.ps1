function Send-GraphMail {
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
        [Parameter(Mandatory=$false)]$Flag,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Low','High')] $Importance,
        [Parameter(Mandatory=$false,ParameterSetName='Attach')]$Attachments,
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
switch ($PSBoundParameters.ContainsKey('flag')) {
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
            Foreach ($Singleattach In $Attachment){ #OKay as you are reading here, This should fixed to support multiple attachment, Each attach should have its own ContentType.
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


Send-mgUsermail -UserId (Get-MgContext).Account -BodyParameter $Body

}

#Send-GraphMail -Subject "sdfsdf" -MessageFormat HTML -To @('to1@domain.com','to2@domain.com') -Bcc 'bcc1@dp,aom/cp,' -Importance High -Attachment C:\MyFile.txt -DocumentType 'text/plain' -Body "sdfsfsdfsdf"
