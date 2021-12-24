<#PSScriptInfo
.VERSION 1.0.0.0
.GUID 163f0d06-5bef-4d9a-bf8b-0c353b92ffc0
.AUTHOR Faris Malaeb
.COMPANYNAME powershellcenter.com
.COPYRIGHT
.TAGS SSL, Certificate, Scan
.LICENSEURI
.PROJECTURI https://www.powershellcenter.com/2021/12/23/sslexpirationcheck/
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA
#>

<# 
.DESCRIPTION 
 Scan website/IP for certificate details, including Expiration date, issuer date, URL, CN, the script also can run the scan using an old protocol such as SSLv3 for old webservers. 
#> 
[CmdletBinding(DefaultParameterSetName='Default')]
param(
[parameter(mandatory=$true)]$FilePath,
[parameter(mandatory=$false)]
[validateset("Tls","Tls11","Tls12","Ssl3","Default")]$ProtocolVersion='Default',
[parameter(mandatory=$false)]$SaveAsTo,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSendTo,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailFrom,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSMTPServer,
[parameter(mandatory=$false,ParameterSetName="email")]$EmailSMTPServerPort="25",
[parameter(mandatory=$false,ParameterSetName="email")][switch]$EmailSMTPServerSSL=$false,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSubject
)


if (!(Test-Path $FilePath)){Throw "Incorrect Source Path."}
$Fullresult=@()
$CertificateList=Get-Content -Path $FilePath
[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
Foreach($url in $CertificateList){
Try{
$results=[PSCustomObject]@{
        URL=''
        StartDate=''
        EndDate=''
        Issuer=''
        Subject=''
        Protocol=''
    }
    if ($url -match '([a-z]+|[A-Z]+):\/\/'){
        $url=$url.Substring($Matches[0].Length)
        }
    if ($url -match '\/$'){
    $url=$url.Substring(0,$url.Length-1)
    }
Try{
$socket = New-Object Net.Sockets.TcpClient($url, 443)
}
Catch{
write-host 'Unable to connect, maybe site is down?!'
$_.exception.message
}
$stream = $socket.GetStream()
$sslStream = New-Object System.Net.Security.SslStream($stream,$false,({$True} -as [Net.Security.RemoteCertificateValidationCallback]))
$sslStream.AuthenticateAsClient($url,$null,[System.Security.Authentication.SslProtocols]$ProtocolVersion,$false)         
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
$results.protocol=$ProtocolVersion
$Fullresult+=$results
}
Catch{
Write-Host $URL -NoNewline -ForegroundColor red " -- ERROR --> " $_.exception.Message
Write-Host "`nMaybe Unsupported protocol.."
$results.URL=$url
$results.StartDate=$_.exception.Message
$results.EndDate="Maybe Unsupported protocol.."
$Fullresult+=$results

}

}
Write-Host "`nThe Full result are as the following"
return $Fullresult 

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
 

