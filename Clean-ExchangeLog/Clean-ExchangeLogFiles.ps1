<#PSScriptInfo

.VERSION 1.0.0

.GUID eead94fc-a7f7-4ed0-8b58-d089214270bd

.AUTHOR Faris Malaeb

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES WebAdministration

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

#Requires -Module WebAdministration

<# 

.DESCRIPTION 
 This Script cleans Exchange Server Logs 2016/2019 logs generated from the service, it also support auto discover for IIS and Exchange directories. This wont remove any log related to database. The script can be used to calculate only or simlulate delete or perform an actual deletion to save space

#>
[Cmdletbinding(DefaultParameterSetName='DontTakeAction')]
Param(
[parameter(Mandatory=$false,ParameterSetName="TakeAction")][switch]$DeleteLogs,
[parameter(Mandatory=$False,ParameterSetName="TakeAction")][switch]$SimulateDeleteLogs,
[parameter(Mandatory=$false,ParameterSetName="DontTakeAction",Position=0)][switch]$JustCalculate,
[parameter(Mandatory=$False,ParameterSetName="DontTakeAction")]
[parameter(Mandatory=$False,ParameterSetName="TakeAction")]
[ValidateScript({If ([int]$_ -gt 0) {
            $True
        } Else {
          Throw "Number Of LogsOlderXDays Should Be 1 Or Higher." 
        }})]$LogsOlderXDays=1,
[parameter(Mandatory=$False,ParameterSetName="DontTakeAction")]
[parameter(Mandatory=$False,ParameterSetName="TakeAction")]
[ValidatePattern('^[a-zA-Z]:\\')]
[ValidateNotNull()]
[system.collections.arraylist]$ExtraFolderToAdd
)


Function Get-AllFoldersTotalItemsSize{
Param(
[cmdletbinding()]
[parameter(mandatory=$true,Position=0,ValueFromPipeline)]$FolderList,
[parameter(mandatory=$true)][int32]$Olderthan
)

Begin{
Write-host "Building Folders list, Please wait..." -ForegroundColor Green
   
}
Process{

    $AllItemsSize=@()
    $TotalItemsize=0
    $ResultTable=@{}
   
   $AllItemsSize+=(@(Get-ChildItem $FolderList -Recurse -ErrorAction SilentlyContinue | Where-Object {($_.CreationTime -lt ((get-date).AddDays(-$Olderthan))) -and ($_.PSIsContainer -like $false) -and (($_.Extension -like "*.log") -or ($_.Extension -like "*.blg") -or ($_.Extension -like "*.etl"))}).foreach({$_.length }))
    $TotalItemsize=($AllItemsSize | Measure-Object -Sum).Sum
    $ResultTable.Add($FolderList,$TotalItemsize)
    Return $ResultTable
}


}


Function Get-AllRequiredFolder{


    $ExInstall=(Get-ItemProperty HKLM:\SOFTWARE\Microsoft\ExchangeServer\v15\Setup).MsiInstallPath
    [system.collections.arraylist]$PossibleLogs=@()
    
    if ($ExtraFolderToAdd){$PossibleLogs+=$ExtraFolderToAdd}
    #------- Exchange Log Path----------------
        $GetTransportServiceParam =@("ConnectivityLogPath",
        "MessageTrackingLogPath",
        "IrmLogPath",
        "ActiveUserStatisticsLogPath",
        "ServerStatisticsLogPath",
        "ReceiveProtocolLogPath",
        "RoutingTableLogPath",
        "SendProtocolLogPath",
        "QueueLogPath",
        "LatencyLogPath",
        "GeneralLogPath",
        "WlmLogPath",
        "AgentLogPath",
        "FlowControlLogPath",
        "ProcessingSchedulerLogPath",
        "ResourceLogPath",
        "DnsLogPath",
        "JournalLogPath",
        "TransportMaintenanceLogPath",
        "TransportHttpLogPath",
        "RequestBrokerLogPath",
        "StorageRESTLogPath",
        "AgentGrayExceptionLogPath")
        $GetTransportService=Get-TransportService -Identity $env:COMPUTERNAME
        $PossibleLogs+= ($GetTransportServiceParam.ForEach({($GetTransportService).($_).PathName}) | Where-Object {$_ -notlike $null})

      $GetFrontendTransportServiceParam=@("ConnectivityLogPath",
        "ReceiveProtocolLogPath",
        "RoutingTableLogPath",
        "SendProtocolLogPath",
        "AgentLogPath",
        "DnsLogPath",
        "ResourceLogPath",
        "AttributionLogPath",
        "ProxyDestinationsLogPath",
        "TopInboundIpSourcesLogPath"
        )
        $GetFrontendTransportService=Get-FrontendTransportService -Identity $env:COMPUTERNAME
        $PossibleLogs+=($GetFrontendTransportServiceParam.ForEach({($GetFrontendTransportService).($_).PathName})  | Where-Object {$_ -notlike $null})

        $GetMailboxTransportServiceParam=@("ConnectivityLogPath"
            "ReceiveProtocolLogPath"
            "DnsLogPath"
            "RoutingTableLogPath"
            "SendProtocolLogPath"
            "MailboxSubmissionAgentLogPath"
            "SyncDeliveryLogPath"
            "MailboxDeliveryAgentLogPath"
            "MailboxDeliveryHttpDeliveryLogPath"
            "MailboxDeliveryThrottlingLogPath"
            "AgentGrayExceptionLogPath")
            $GetMailboxTransportService=Get-MailboxTransportService -Identity $env:COMPUTERNAME
       $PossibleLogs+=($GetMailboxTransportServiceParam.ForEach({($GetMailboxTransportService).($_).PathName})  | Where-Object {$_ -notlike $null})

        if (Test-Path(Get-MailboxServer -Identity $env:COMPUTERNAME).CalendarRepairLogPath.Pathname){$PossibleLogs+=(Get-MailboxServer -Identity $env:COMPUTERNAME).CalendarRepairLogPath.Pathname}
        if (test-path(Get-MailboxServer -Identity $env:COMPUTERNAME).LogPathForManagedFolders.Pathname){$PossibleLogs+=(Get-MailboxServer -Identity $env:COMPUTERNAME).LogPathForManagedFolders.Pathname}
        
        $PossibleLogs= $PossibleLogs.Where({$_ -notlike "*v15\Logging*"})

   (Get-Website).name.foreach{
            $CurrentSiteLog=(get-item "IIS:\Sites\$_").LogFile.directory
            if (($CurrentSiteLog -like "%*") -and ($CurrentSiteLog -match '(?<SysVar>\w+)')){
                $UpdatedVar= get-item env:\$($Matches.SysVar)
                 $PossibleLogs+=$CurrentSiteLog -replace "%\w+%" , $UpdatedVar.value
                }
            Else{
             $PossibleLogs+=$CurrentSiteLog
            }
            }      
        
    $PossibleLogs+=join-path $ExInstall -ChildPath "logging"
    Write-host "Validating Paths, Please wait.." -ForegroundColor Green
        Foreach ($FoldersInPossibleLogs in @($PossibleLogs)){
            if (!(Test-Path -Path $FoldersInPossibleLogs)){
            $PossibleLogs.Remove($FoldersInPossibleLogs)
            }
        }
    write-host "Validation is completed..."
    Return ($PossibleLogs | Select-Object -Unique)
    
}

Function CalculateSizes{
 $GetAllFolders= Get-AllRequiredFolder | Get-AllFoldersTotalItemsSize -Olderthan $LogsOlderXDays
          $GetAllFolders | Format-Table Name,@{N="Value in MB";E={[math]::Round($_.Value /1MB,2)}} -AutoSize
          Write-Host "The Total Space used by Exchange and IIS Logs is (MB): " -NoNewline
          Write-host $([math]::Round(($GetAllFolders.values | Measure-Object -Sum).Sum /1MB,2)) -ForegroundColor Green
}



Function DeleteLogs{
param(
$FolderlistToRemove,
$NumberOfDaysToDelete,
[switch]$IsSimulation
)
if ($IsSimulation){
write-host "`nNO delete operation will be performed, Log will be stored in the same script directory."
Write-host "Simulation Started.. Please wait"-NoNewline
$FileNameToLog=(Join-Path $PSScriptRoot -ChildPath "FilesForRemoval $(Get-Date -Format "HHmmss").txt")
        $FolderlistToRemove.foreach({
        Write-Host "." -NoNewline
        @(Get-ChildItem $_ -Recurse -ErrorAction Stop | Where-Object {($_.CreationTime -lt ((get-date).AddDays((-$NumberOfDaysToDelete)))) -and ($_.PSIsContainer -like $false) -and (($_.Extension -like "*.log") -or ($_.Extension -like "*.blg") -or ($_.Extension -like "*.etl"))} ).foreach({
            Add-Content $FileNameToLog -Value $_.fullname
            
         })
        })

}
    else{
   

        Write-Host "`nIts Expected to have some failure as logs might be still in used by other process..."
        Write-host "Operation started... Removing`n "-NoNewline
        $FolderlistToRemove.foreach({
        Write-Host "." -NoNewline -ForegroundColor Red
        @(Get-ChildItem $_ -Recurse -ErrorAction Stop | Where-Object {($_.CreationTime -lt ((get-date).AddDays((-$NumberOfDaysToDelete)))) -and ($_.PSIsContainer -like $false) -and (($_.Extension -like "*.log") -or ($_.Extension -like "*.blg") -or ($_.Extension -like "*.etl"))} ).foreach({
         Trap {
            $Error[1].Exception
            Continue
            }
        Remove-Item $_.fullname -Force -ErrorAction Stop
            
         })
        })
        }

}
try{

if ((Get-PSSnapin).name -notcontains  "Microsoft.Exchange.Management.PowerShell.SnapIn"){
    Write-host "Adding Exchange Snapin.."
    Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn}
}
Catch{
Throw 'Cannot load Exchange Management PowerShell Snapin, "Microsoft.Exchange.Management.PowerShell.SnapIn"'
}


if (($PSBoundParameters.Keys.Count -eq 0)-or ($PSCmdlet.ParameterSetName -like "DontTakeAction")){CalculateSizes}

if ($PSCmdlet.ParameterSetName -like "TakeAction"){
    $GetAllFolder=Get-AllRequiredFolder
    Write-Host "The Operation will Start in 10 Sec, if you want to stop, then press CTRL+C" -NoNewline
    for ($i = 0; $i -lt 10; $i++)
        { 
            Write-Host "." -NoNewline
            Start-Sleep 1

        }

  if ($PSBoundParameters.ContainsKey("SimulateDeleteLogs")){DeleteLogs -FolderlistToRemove $GetAllFolder -NumberOfDaysToDelete $LogsOlderXDays -IsSimulation}
  else{
    DeleteLogs -FolderlistToRemove $GetAllFolder -NumberOfDaysToDelete $LogsOlderXDays 
    }
}


#USE IT ON YOUR OWN RISK