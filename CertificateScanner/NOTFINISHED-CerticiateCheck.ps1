param(
[parameter(mandatory=$true)]$FilePath,
[parameter(mandatory=$false)]$NoCertValidation=$true,
[parameter(mandatory=$false)]
[validateset("Tls","TLS11","Tls12","Ssl3","SystemDefault")]$ProtocolVersion='TLS11',
[parameter(mandatory=$false)]$SaveAsTo
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



[Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
Try{
$results=[PSCustomObject]@{
        URL=''
        StartDate=''
        EndDate=''
    }

$req = [Net.HttpWebRequest]::Create($url)
$req.GetResponse() |Out-Null
$results.URL=$url
$results.StartDate=$req.ServicePoint.Certificate.GetEffectiveDateString()
    if ([datetime]$req.ServicePoint.Certificate.GetExpirationDateString() -le (Get-Date).Date){
    Write-Host $url -NoNewline -ForegroundColor Yellow
    Write-Host " EXPIRD..." -ForegroundColor red
        }
$results.EndDate=$req.ServicePoint.Certificate.GetExpirationDateString()
$Fullresult+=$results
$Fullresult
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
$Fullresult | ft

