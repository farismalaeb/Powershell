<#PSScriptInfo
.VERSION 2.0.0.0
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
 Update 28-Feb-2023
 SiteToScan parameter added to scan on the fly without having to load from file
 If the site running certificate on a different port the script scan that port, but you need to set the port number using color
 Default protocol is set by default to TLS12
 Minor enhancement in the processing
#> 
[CmdletBinding(DefaultParameterSetName='Default')]
param(
[Alias("FilePath")]
[parameter(mandatory=$true,ParameterSetName="ReadFromFile")]$LoadFromFile,
[parameter(mandatory=$true,ParameterSetName="Online")]$SiteToScan,
[parameter(mandatory=$false)]
[validateset("Tls","Tls11","Tls12","Ssl3","Default")]$ProtocolVersion='TLS12',
[parameter(mandatory=$false,ParameterSetName="ReadFromFile")]$SaveAsTo,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSendTo,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailFrom,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSMTPServer,
[parameter(mandatory=$false,ParameterSetName="email")]$EmailSMTPServerPort="25",
[parameter(mandatory=$false,ParameterSetName="email")][switch]$EmailSMTPServerSSL=$false,
[parameter(mandatory=$true,ParameterSetName="email")]$EmailSubject
)

Function ScanSiteInformaiton{
    param(
        $URLScanSiteInfo
    )
    if ($URLScanSiteInfo -match '([a-z]+|[A-Z]+):\/\/'){
        $URLScanSiteInfo=$URLScanSiteInfo.Substring($Matches[0].Length)
        }
    if ($URLScanSiteInfo -match '\/$'){
        $URLScanSiteInfo=$URLScanSiteInfo.Substring(0,$URLScanSiteInfo.Length-1)
        }
    if ($URLScanSiteInfo -match '(.*?):(.*)'){
    $PortToScan= $Matches[2]
    $URLScanSiteInfo=$Matches[1]
    }
    Else{$PortToScan=443}
    [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    Try{
        $socket = New-Object Net.Sockets.TcpClient($URLScanSiteInfo, $PortToScan)
        }
        Catch{
        write-host 'Unable to connect, maybe site is down?!'
        $_.exception.message
        }
        
                $stream = $socket.GetStream()
                $sslStream = New-Object System.Net.Security.SslStream($stream, $false, ({ $True } -as [Net.Security.RemoteCertificateValidationCallback]))
                $sslStream.AuthenticateAsClient($URLScanSiteInfo, $null, [System.Security.Authentication.SslProtocols]$ProtocolVersion, $false)         
                $socket.close()
                Try{
                    $results=[PSCustomObject]@{
                            URL=''
                            StartDate=''
                            EndDate=''
                            Issuer=''
                            Subject=''
                            Protocol=''
                        }
                        
                    $results.URL=$URLScanSiteInfo
                    $results.StartDate=$sslStream.RemoteCertificate.GetEffectiveDateString()
                        if ([datetime]$sslStream.RemoteCertificate.GetExpirationDateString() -le (Get-Date).Date){
                            }
                    $results.EndDate=$sslStream.RemoteCertificate.GetExpirationDateString()
                    $results.Issuer=$sslStream.RemoteCertificate.Issuer
                    $results.Subject=$sslStream.RemoteCertificate.Subject
                    $results.protocol=$ProtocolVersion

    }
    Catch{
        Write-Host $URL -NoNewline -ForegroundColor red " -- ERROR --> " $_.exception.Message
        Write-Host "`nMaybe Unsupported protocol.."
        $results.URL=$url
        $results.StartDate=$_.exception.Message
        $results.EndDate="Maybe Unsupported protocol. Try using -ProtocolVersion Tls12"
        $Fullresult+=$results
    }

    Return $results
}



## Start for File Load and Scan
if ($PSCmdlet.ParameterSetName -eq "ReadFromFile") {
    if (!(Test-Path $LoadFromFile)){Throw "Incorrect Source Path."}
    $Fullresult=@()
    $CertificateList=Get-Content -Path $LoadFromFile
    Foreach($url in $CertificateList){
    $siteresults=ScanSiteInformaiton -URLScanSiteInfo $url
    $Fullresult+=$siteresults
    }
    return $Fullresult 
}

if ($pscmdlet.ParameterSetName -eq "Online") {
if (($SiteToScan.gettype()).BaseType -like "*Array"){ }#LOOOOP all}

   $Fullresult=ScanSiteInformaiton -URLScanSiteInfo $SiteToScan 
   return $Fullresult 
}



    if ($PSBoundParameters.Keys -like "SaveAsTo"){
    try{
        $Fullresult | Export-Csv -Path $SaveAsTo -NoTypeInformation
        }
        catch{
        Throw $_.exception.message
        }
    }
  
    if (($PSCmdlet.ParameterSetName -like "email") -and (($PSBoundParameters.Keys -like "SaveAsTo")  -or ($PSBoundParameters.Keys -like "Online"))){
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
        Write-Host "Sending Email ...[][][]"
        Send-MailMessage @sendmail
        Write-Host "Email Sent ...>>>>"
        }
        Catch{
        Throw $_.exception.message 
        }
    }
 
   
 