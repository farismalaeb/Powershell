param(
[parameter(mandatory=$true)]$FilePath,
[parameter(mandatory=$true)]$NoCertValidation,
[parameter(mandatory=$true)]
[parameter(mandatory=$true)]
[validateset("TLS1.0","TLS1.1","TLS1.2","SSLv3","SSLv2")]$ProtocolVersion,
[parameter(mandatory=$true)]$SaveAsTo
)

if (!(Test-Path $FilePath)){Throw "Path Incorrect"}

$CertificateList=Get-Content -Path "C:\Users\rescu\cert.txt"

Foreach($url in $CertificateList){
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
    if ($req.ServicePoint.Certificate.GetExpirationDateString() -le (Get-Date).Date){
    Write-Host $url -NoNewline -ForegroundColor Yellow
    Write-Host " EXPIRD..." -ForegroundColor red
        }
$results.EndDate=$req.ServicePoint.Certificate.GetExpirationDateString()
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
$Fullresult





