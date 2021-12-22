[CmdletBinding(DefaultParameterSetName='Default')]
param(
[parameter(mandatory=$true)]$FilePath,
[parameter(mandatory=$false)]$NoCertValidation=$true,
[parameter(mandatory=$false)]
[validateset("Tls","Tls11","Tls12","Ssl3","SystemDefault")]$ProtocolVersion='SystemDefault',
[parameter(mandatory=$false)]$SaveAsTo,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSendTo,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailFrom,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSMTPServer,
[parameter(mandatory=$false,ParameterSetName="email")]$EmailSMTPServerPort="25",
[parameter(mandatory=$false,ParameterSetName="email")][bool]$EmailSMTPServerSSL=$false,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSubject
)


if (!(Test-Path $FilePath)){Throw "Incorrect Source Path."}
$Fullresult=@()
$CertificateList=Get-Content -Path $FilePath

Foreach($url in $CertificateList){

    switch ($NoCertValidation){
        $True  {[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }}
        $false {[Net.ServicePointManager]::ServerCertificateValidationCallback = { $False}}
    }

    if ($PSBoundParameters.Keys -like "ProtocolVersion"){
         [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::$ProtocolVersion
    }



Try{
$results=[PSCustomObject]@{
        URL=''
        StartDate=''
        EndDate=''
        Issuer=''
        Subject=''
    }
    if ($url -match '([a-z]+|[A-Z]+):\/\/'){
        $url=$url.Substring($Matches[0].Length)
        }
    if ($url -match '\/$'){
    $url=$url.Substring(0,$url.Length-1)
    }

$socket = New-Object Net.Sockets.TcpClient($url, 443)
$stream = $socket.GetStream()
$sslStream = New-Object System.Net.Security.SslStream($stream,$false,({$True} -as [Net.Security.RemoteCertificateValidationCallback]))
$sslStream.AuthenticateAsClient($url)
$socket.close()
$results.URL=$url
$results.StartDate=$sslStream.RemoteCertificate.GetEffectiveDateString()
    if ([datetime]$sslStream.RemoteCertificate.GetExpirationDateString() -le (Get-Date).Date){
    Write-Host $url -NoNewline -ForegroundColor Yellow
    Write-Host " EXPIRD..." -ForegroundColor red
        }
$results.EndDate=$sslStream.RemoteCertificate.GetExpirationDateString()
$results.Issuer=$sslStream.RemoteCertificate.Issuer
$results.Subject=$sslStream.RemoteCertificate.Subject
$Fullresult+=$results
}
Catch{
Write-Host $URL -NoNewline -ForegroundColor red " -- ERROR --> " $_.exception.Message
$results.URL=$url
$results.StartDate=$_.exception.Message
$results.EndDate=$_.exception.Message
$Fullresult+=$results

}

}
Write-Host "`nThe Full result are as the following"
$Fullresult | format-list *

    if ($PSBoundParameters.Keys -like "SaveAsTo"){
    try{
        $Fullresult | Export-Csv -Path $SaveAsTo -NoTypeInformation
        }
        catch{
        Throw $_.exception.message
        }
    }

    if ($PSCmdlet.ParameterSetName -like "email"){
       try{
       $SendMail=@{
       From=$EmailFrom
       To =$EmailSendTo
       Subject =$EmailSubject
       Body =($Fullresult | Out-String)
       SmtpServer =$EmailSMTPServer 
       Credential =(Get-Credential)
       Port= $EmailSMTPServerPort
       UseSsl = $EmailSMTPServerSSL
       }
        Send-MailMessage @sendmail 
        }
        Catch{
        Throw $_.exception.message 
        }
    }
 

