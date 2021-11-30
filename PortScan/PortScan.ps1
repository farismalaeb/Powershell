
<#PSScriptInfo

.VERSION 1.0.0.0

.GUID 1fc69e57-b727-43ce-b317-8ad9c7d020b0

.AUTHOR Faris Malaeb

.COMPANYNAME 

.COPYRIGHT 

.TAGS Port,External Scanning, Security, TCP/IP

.LICENSEURI 

.PROJECTURI https://github.com/farismalaeb/Powershell/tree/master/PortScan

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 Perform External Port Scanning 

#> 
[cmdletbinding()]
param(
[parameter(Mandatory=$true)]$HostToScan,
[parameter(Mandatory=$true,ParameterSetName="Range")][int]$StartingPort,
[parameter(Mandatory=$true,ParameterSetName="Range")][int]$EndingPort,
[parameter(Mandatory=$true,ParameterSetName="SelectivePort")][array]$SelectivePort
)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$OpenPorts=@()

if ($PSCmdlet.ParameterSetName -like "Range"){
    $Body=@{
    remoteHost =$HostToScan
    start_port = $PSBoundParameters['StartingPort']
    end_port = $PSBoundParameters['EndingPort']
    normalScan = 'Yes'
    scan_type = 'connect'
    ping_type = 'none'
    }



try{

    $WebResult=(Invoke-RestMethod -Method Post -Body $Body -Uri 'https://www.ipfingerprints.com/scripts/getPortsInfo.php' -ErrorAction Stop).PortScanInfo.Split("`n") |where {$_ -match "(^\d*)\/\D{3}"}
    if (!($WebResult)){
        Write-Host "No result return, Please check the site name or IP if its valid or not" -ForegroundColor Red 
        return
        }

    foreach ($Singleline in $WebResult){

    $FilteredResult=[pscustomobject]@{
        Host=$PSBoundParameters['HostToScan']
        Port=""
        Result=""
    }
      $FilteredResult.Port=([regex]::Matches($Singleline,"^\d*")).value
      if ($Singleline -like "*open*"){$FilteredResult.Result="Open"}
      Else{$FilteredResult.Result="Filtered"}
        $OpenPorts+=$FilteredResult
    }


}


Catch{
Write-Host $_.exception.Message
}
}

if ($PSCmdlet.ParameterSetName -like "SelectivePort"){



foreach ($SinglePort in $SelectivePort){
if ($SinglePort.gettype().name -notlike 'int32'){
    Write-Host "$($SinglePort) is an invalid port number"
    return
    }
    $Body=@{
        remoteHost =$HostToScan
        start_port = $SinglePort
        end_port = $SinglePort
        normalScan = 'Yes'
        scan_type = 'connect'
        ping_type = 'none'
        }
    
       $SingleFilteredResult=[pscustomobject]@{
        Host=$PSBoundParameters['HostToScan']
        Port=""
        Result=""
        }


        Try{
    $SingleWebRequest=(Invoke-RestMethod -Method Post -Body $Body -Uri 'https://www.ipfingerprints.com/scripts/getPortsInfo.php' -ErrorAction Stop).PortScanInfo.Split("`n") |where {$_ -match "(^\d*)\/\D{3}"}
        if (!($SingleWebRequest)){
        Write-Host "No result return, Please check the site name or IP if its valid or not" -ForegroundColor Red 
        return
        }

      $SingleFilteredResult.Port=([regex]::Matches($SingleWebRequest,"^\d*")).value
      if ($SingleWebRequest -like "*open*"){ $SingleFilteredResult.Result="Open"}
      Else{ $SingleFilteredResult.Result="Filtered"}
        $OpenPorts+=$SingleFilteredResult
    }
    catch{
    Write-Host $_.exception.Message

    }
    
  }

}    
    
return  $OpenPorts






