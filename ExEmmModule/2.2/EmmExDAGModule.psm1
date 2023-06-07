<#PSScriptInfo
.VERSION 2.3
.AUTHOR Faris Malaeb
.PROJECTURI https://www.powershellcenter.com/
.DESCRIPTION 
 This Powershell module will Place your Exchange Server DAG in maintenance Mode
 Also you can remove Exchange DAG from Maintenance Mode.
 Available Commands
    Start-EMMDAGEnabled: Set your Exchange Server to be in Maintenance Mode.
    Stop-EMMDAGEnabled: Remove Exchange from maintenanace Mode
    Test-EMMReadiness: Test the environment for readiness to go in maintenance Mode
   

#> 
Function Check-ScriptReadiness{
param(
$ServerName,
$AltServer
)
        if (((Test-NetConnection -Port 80 -ComputerName $PSBoundParameters['ServerName']).TcpTestSucceeded -like $true) -and (Test-NetConnection -Port 80 -ComputerName $PSBoundParameters['AltServer']).TcpTestSucceeded -like $true){
        $isadmin=[bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
        switch ($isadmin)
        {
            $true {return 1}
            $false {return 0}
           
        }
       
       }
       Else{
        write-host "Operation failed, please check if the computer and the Alternative Server are reachable" -ForegroundColor Red
        Write-host  $Error[0]
        break
       }


}

Function Start-EMMDAGEnabled {
   
    Param(
        [parameter(mandatory=$false,ValueFromPipeline=$true,Position=0)]$ServerForMaintenance,
        [parameter(mandatory=$false)][ValidatePattern("(?=^.{1,254}$)(^(?:(?!\d+\.|-)[a-zA-Z0-9_\-]{1,63}(?<!-)\.?)+(?:[a-zA-Z]{2,})$)")][string]$ReplacementServerFQDN,
        [parameter(Mandatory=$false)][switch]$IgnoreQueue,
        [parameter(Mandatory=$false)][switch]$IgnoreCluster,
        [parameter(Mandatory=$false)][switch]$SkipDatabaseHealthCheck,
        [parameter(Mandatory=$false)][switch]$DisableMSExchangeFrontEndTransport

    )

        Begin{
        AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking Readiness... Please wait" -MessageColor Yellow -ProgressState "Starting" -ProgressPercent 3 
            $ErrorActionPreference="Stop"
            $ReadyToExecute=Check-ScriptReadiness -ServerName $PSBoundParameters['ServerForMaintenance'] -AltServer $PSBoundParameters['ReplacementServerFQDN']
            if ($ReadyToExecute -eq 0){Write-Host "Please Make sure that you execute Powershell as Admin" -ForegroundColor Red
                return
            }
        [hashtable]$ExMainProgress=[ordered]@{}
        if ($PSBoundParameters.ContainsKey('SkipDatabaseHealthCheck')){
        AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "DB Health check will be ignored as the -SkipDatabaseHealthCheck is selected.`nIts a recommended to use this option in production environment." -MessageColor red
        Write-Host "Please check the online manual and ensure to follow the best practices"
        }
        }

        Process{
            AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Preparing $($PSBoundParameters['ServerForMaintenance']) to be placed in Maintinance Mode" -MessageColor Yellow -ProgressState "Turnning Off HubTransport Activities..."  -ProgressPercent 10 
            $Step1=Set-EMMHubTransportState -Servername $PSBoundParameters['ServerForMaintenance'] -Status Draining
            switch ($PSBoundParameters.Containskey('IgnoreQueue')){
                $true {write-host "Queue Check... Skipped" -ForegroundColor Yellow }
                $false{
                $QState=QueueFailure -ServernameToCheck $PSBoundParameters['ServerForMaintenance']
            if ($QState -eq 1){
                    AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Message Redirection Process will Start, expected time to finish is 60 seconds." -MessageColor Yellow -ProgressState "Redirecting Messages..." -ProgressPercent 25 
                    Start-EMMRedirectMessage -SourceServer $PSBoundParameters['ServerForMaintenance'] -ToServer $PSBoundParameters['ReplacementServerFQDN']
                    Start-EMMRedirectMessage -SourceServer $PSBoundParameters['ServerForMaintenance'] -ToServer $PSBoundParameters['ReplacementServerFQDN']  -CheckOnly
                    Start-Sleep -Seconds 2
                    $Qlength=(Get-Queue -server $PSBoundParameters['ServerForMaintenance'] | Where-Object {($_.DeliveryType -notlike "Shadow*") -and ($_.DeliveryType -notlike "Undefined") }| Select-Object Messagecount | Measure-Object -Sum -Property MessageCount).Sum
                }
                }
                }
            Switch($PSBoundParameters.Containskey('DisableMSExchangeFrontEndTransport')){

                $true {AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Stopping SMTP and shutting down MSExchangeFrontEnd Transport Service." -MessageColor Yellow -ProgressState "Stopping SMTP" -ProgressPercent 100
                (Get-WmiObject -ComputerName $PSBoundParameters['ServerForMaintenance'] -Query 'select * from win32_service where name like "MSExchangeFrontEndTransport"').stopService() 
                }
            }

            Switch($PSBoundParameters.Containskey('IgnoreCluster')){
                        $true { AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Skipping Cluster MGMT as user requests." -MessageColor Yellow -ProgressState "Skipping Cluster" -ProgressPercent 50
                                $step3="Skipped"}
                        $false { AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Starting Cluster MGMT." -MessageColor Yellow -ProgressState "Pausing $($PSBoundParameters['ServerForMaintenance']) " -ProgressPercent 50
                                $step3=Set-EMMClusterConfig -ClusterNode $PSBoundParameters['ServerForMaintenance'] -PauseOrResume PauseThisNode}
                    }
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Starting Exchange Database Managment" -MessageColor Yellow -ProgressState "Moving Database to another node" -ProgressPercent 70
            switch ($PSBoundParameters.Containskey('SkipDatabaseHealthCheck')){

            $true {Set-EMMDBActivationMoveNow -ServerName $PSBoundParameters['ServerForMaintenance'] -ActivationMode BlockMode -TimeoutBeforeManualMove 120 -SkipValidation}
            $false {Set-EMMDBActivationMoveNow -ServerName $PSBoundParameters['ServerForMaintenance'] -ActivationMode BlockMode -TimeoutBeforeManualMove 120  }
            }
            
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Switching ServerComponentState ServerWideOffline to Off" -MessageColor Yellow -ProgressState "Updating ServerWideOffline" -ProgressPercent 95
            Set-ServerComponentState $PSBoundParameters['ServerForMaintenance'] -Component ServerWideOffline -State Inactive -Requester Maintenance -ErrorAction Stop
            $step5=get-ServerComponentState $PSBoundParameters['ServerForMaintenance'] -Component ServerWideOffline

            Write-Host "All Commands are completed, and below are the result...`n"-ForegroundColor Yellow
            $ExMainProgress.Add("HubTransport Draining",$Step1)
            if (($Qlength -eq 0) -or ($Qlength -like $null)){$ExMainProgress.Add("Queue Length Status","All Transfared.")}
            Else{$ExMainProgress.Add("Queue Length Status",$Qlength)}
            $ExMainProgress.Add("Cluster Node",$step3)
            $ExMainProgress.Add("Activation Policy",(Get-MailboxServer -Identity $PSBoundParameters['ServerForMaintenance']).DatabaseCopyAutoActivationPolicy)
            $ExMainProgress.Add("ServerWide",$step5.State)

        }
        
        End{
       Return $ExMainProgress | Format-Table -AutoSize -Wrap


        }
}
Export-ModuleMember Start-EmmDAGEnabled

Function AddEmptylines{
param(
    [parameter(mandatory=$true)]$numberoflines,
    [parameter(mandatory=$true)]$MessageToIncludeAtTheEnd,
    [parameter(mandatory=$True)]$MessageColor,
    [parameter(mandatory=$false)]$ProgressState,
    [parameter(mandatory=$false)]$ProgressPercent


    )
    $numofline=0
    while($numofline -lt $PSBoundParameters['numberoflines']){
        Write-Host ""
        $numofline++
    }
    Write-Host $($PSBoundParameters['MessageToIncludeAtTheEnd']) -ForegroundColor $PSBoundParameters['MessageColor']
    if ($PSBoundParameters['ProgressState']){
    Write-Progress -Activity $PSBoundParameters['MessageToIncludeAtTheEnd'] -Status $PSBoundParameters['ProgressState'] -PercentComplete $PSBoundParameters['ProgressPercent']
    }
    
}

Function Stop-EMMDAGEnabled {
   
    Param(
        [parameter(mandatory=$false,ValueFromPipeline=$true,Position=0)]$ServerInMaintenance,
        [parameter(Mandatory=$false)][switch]$IgnoreCluster,
        [parameter(mandatory=$false)][validateset("IntrasiteOnly","Unrestricted")]$ServerActivationMode="Unrestricted",
        [parameter(Mandatory=$false)][switch]$EnableMSExchangeFrontEndTransport
    )

        Begin{
            $ErrorActionPreference="Stop"
            [hashtable]$ExOutMainProgress=[ordered]@{}
        }

        Process{
            Write-Host "Preparing $($PSBoundParameters['ServerInMaintenance']) for Activation..." -ForegroundColor Yellow 
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Taking the Server Out of Maintenance mode..." -MessageColor Yellow -ProgressState "Enabling ServerWideOffline component" -ProgressPercent 15
            Set-ServerComponentState $PSBoundParameters['ServerInMaintenance'] -Component ServerWideOffline -State active -Requester Maintenance
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Configuring cluster if required..." -MessageColor Yellow -ProgressState "Cluster Configuration" -ProgressPercent 35
            switch($PSBoundParameters.Containskey('IgnoreCluster')){
                $true {write-host "Cluster Config are Skipped";$outstep1="Skipped"}
                $false {$outstep1=Set-EMMClusterConfig -ClusterNode $PSBoundParameters['ServerInMaintenance'] -PauseOrResume ResumeThisNode}
            }

            Switch($PSBoundParameters.Containskey('EnableMSExchangeFrontEndTransport')){

                $true {AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Start SMTP and starting down MSExchangeFrontEnd Transport Service." -MessageColor Yellow -ProgressState "Starting SMTP" -ProgressPercent 100
                (Get-WmiObject -ComputerName $PSBoundParameters['ServerForMaintenance'] -Query 'select * from win32_service where name like "MSExchangeFrontEndTransport"').startService() 
                }
            }
            $outStep2=Set-EMMDBActivationMoveNow -ServerName $PSBoundParameters['ServerInMaintenance'] -ActivationMode $ServerActivationMode
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Enabling HubTransport Components..." -MessageColor Yellow -ProgressState "Enabling HubTransport..." -ProgressPercent 60
            $outStep3=Set-EMMHubTransportState -Servername $PSBoundParameters['ServerInMaintenance'] -Status Active
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Enabling Exchange Server Components..." -MessageColor Yellow -ProgressState "All should be done, below are the result, Make sure that there is no failure or other issues" -ProgressPercent 90
              Write-Host "-------- Result for Activating Server " -NoNewline ;Write-Host "$($PSBoundParameters['ServerInMaintenance']) " -ForegroundColor Yellow -NoNewline ;Write-Host " -----------"
              $ExOutMainProgress.Add("ServerWide",(Get-ServerComponentState $PSBoundParameters['ServerInMaintenance'] -Component ServerWideOffline).State)
              $ExOutMainProgress.Add("ClusterNode",$outstep1)
              $ExOutMainProgress.Add("DB Server Activation",$outStep2)
              $ExOutMainProgress.Add("HubTransport",$outStep3)
        }
        
        End{
       return $ExOutMainProgress | Format-Table -AutoSize -Wrap
        }
}
Export-ModuleMember Stop-EMMDAGEnabled


Function Set-EMMHubTransportState {
[CmdletBinding()]
Param(
[parameter(mandatory=$true,ValueFromPipeline=$true,Position=0)]$Servername,
[validateset("Draining","Active")]$Status

)

  Process{
  Write-Host "Configuring Hub Transport to be " -NoNewline; Write-Host "$($PSBoundParameters['Status'])" -ForegroundColor Green -NoNewline ; Write-Host " For " -NoNewline; Write-Host "$($PSBoundParameters['Servername'])" -ForegroundColor Green

    Try
    {    

      if (@((Get-ExchangeServer | Get-ServerComponentState -Component Hubtransport | Where-Object {($_.State -like "Active")  -and  ($_.Serverfqdn -notlike "*$Servername*")}).state).Count -eq 0){
            Write-warning "Ops, there are no more servers with a HubTransport state set to Active State in the environment, Please make sure to have at least one"
            break
            }
            $TransportState=@{
            identity=$PSBoundParameters['servername']
            Component='HubTransport'
            State=$PSBoundParameters['Status']
            Requester="Maintenance"
            }
       Set-ServerComponentState @TransportState
       Start-Sleep -Seconds 2
       $Srvcomstate=(Get-ServerComponentState $PSBoundParameters['servername'] -Component HubTransport).state
       return $Srvcomstate
      
    }
    catch {
        Write-Warning -Message $Error[0]
        break
    }

    }

    End{
       Write-Host "Configs are completed, Now $($PSBoundParameters['servername']) is set to be :" -NoNewline; write-host (Get-ServerComponentState $PSBoundParameters['servername'] -Component HubTransport).state -ForegroundColor Green

    }
    

    
}

Function QueueFailure{
param(
$ServernameToCheck)
    $timer=0
    Write-Host "Restarting HubTransport Server on $($PSBoundParameters['ServernameToCheck'])"
        sleep 2
        Get-Service -ComputerName $PSBoundParameters['ServernameToCheck'] -Name MSExchangeTransport | Restart-Service -Force
        Get-Service -ComputerName $PSBoundParameters['ServernameToCheck'] -Name MSExchangeFrontEndTransport| Restart-Service -Force
        while ($timer -ne 120)
        {
            Trap { 
                Write-Host "." -NoNewline -ForegroundColor RED 
                continue
            }
        Start-Sleep 1

        if (Get-Queue -server $PSBoundParameters['ServernameToCheck'] -ErrorAction stop){
             
              Return 1
        }
          $timer++
        }
        Return 2


}

Function Start-EMMRedirectMessage{
param(
[parameter(mandatory=$True,ValueFromPipeline=$true,Position=0)]$SourceServer,
[parameter(mandatory=$True)][ValidatePattern("(?=^.{1,254}$)(^(?:(?!\d+\.|-)[a-zA-Z0-9_\-]{1,63}(?<!-)\.?)+(?:[a-zA-Z]{2,})$)")][string]$ToServer,
[parameter(mandatory=$False,ValueFromPipeline=$true,Position=0)][switch]$CheckOnly
)

        $counter=0

        switch ($PSBoundParameters.ContainsKey('CheckOnly')) {
              $False {
                Write-Host "Redirecting the Queue..."
                try{
                Redirect-Message -Server $PSBoundParameters['SourceServer'] -Target $PSBoundParameters['ToServer'] -Confirm:$False -ErrorAction Stop
                AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Queue Transfar request sent.." -MessageColor Yellow
                }
                Catch{

                    $_.Exception.Message
                }

              }  
              $True {
                Write-Host "Checking Queue Value, and waiting for it to be 0, the timeout for this process is 60 second, Please wait."
                try{
                do
                {
                  $QL=(Get-Queue -server $PSBoundParameters['SourceServer'] -ErrorAction stop | Where-Object {($_.DeliveryType -notlike "Shadow*") -and ($_.DeliveryType -notlike "Undefined") }| Select-Object Messagecount | Measure-Object -Sum -Property MessageCount).Sum
                  if (($ql -eq 0) -or $($ql -eq $null)){return "Queue Transfer successfully"}
                  Start-Sleep -Seconds 1
                  $counter++
                  if ($counter -eq 60){
                   Write-Host "Queue Transfer was not completed"
                   Write-Host "The Number of remaining Queue is" $($QL)
                   $YesNo=Read-Host "Press Y to continue or any other key to abort the process"
                       if ($YesNo -like "Y"){return "Queue Transfer is not completed, But the user accepted it"}
                       else{
                       Throw "User Aborted Queue Transfar.."
                       }
                   }
                }
                while ($ql -gt 0)
                }
                Catch{
                $_.Exception.Message
                }

              }
              
              

        }

        }

Function Set-EMMClusterConfig {
Param(
[parameter(mandatory=$true,ValueFromPipeline=$true,Position=0)]$ClusterNode,
[parameter(mandatory=$true)][validateset("PauseThisNode","ResumeThisNode")]$PauseOrResume
)

    Process{
        Write-Host "Starting Cluster Management for "-NoNewline ; Write-Host $PSBoundParameters['ClusterNode'] -ForegroundColor Yellow
    try{
          
          Write-Host "Checking Cluster Readiness and resilience" -ForegroundColor Yellow
          $Status=Get-ClusterNode -Cluster (Get-DatabaseAvailabilityGroup) -ErrorAction Stop
          Write-Host "The number of Up Nodes are $(@(($Status | Where-Object {$_.state -like 'up'}).State).count)" -ForegroundColor  Yellow

        if ($PSBoundParameters['PauseOrResume'] -like "PauseThisNode"){
                
         
            if (@($Status | Where-Object {($_.state -like 'up') -and ($_.name -notlike $PSBoundParameters['ClusterNode'])}).count -eq 0){
                Write-Host "WARNING: The number of available clusters is not enough, Please stop and resume one node at least" -ForegroundColor Red
                $Status | Select-Object Name,State,Cluster
                break
                }

            if (($Status | Where-Object{$_.name -like $PSBoundParameters['ClusterNode']}).State -Like "Paused"){
                Write-Host "The node is already disabled...Nothing to do in this step"
                return "Node is Already Paused"
            }
             $clsstate=Suspend-ClusterNode -Name $PSBoundParameters['ClusterNode'] -Cluster (Get-DatabaseAvailabilityGroup) -ErrorAction Stop
                Start-Sleep -Seconds 2
                return $clsstate.State
               }
               ## Resume Cluster node
         if ($PSBoundParameters['PauseOrResume'] -like "ResumeThisNode"){
          if (($Status | Where-Object{$_.name -like $PSBoundParameters['ClusterNode']}).State -Like "Up"){
                Write-Host "Node already Up...Nothing to do in this step"
                return "Node is Already Up"
            }
                $clsresumestate=Resume-ClusterNode -Name $PSBoundParameters['ClusterNode'] -Cluster (Get-DatabaseAvailabilityGroup) -ErrorAction Stop
                Start-Sleep -Seconds 2
                return $clsresumestate.State
             }
                

    }
    Catch {
    Write-host $Error[0].Exception -ForegroundColor Red
    Write-Host "Failed to prepare the cluster, Please check if the computer name is correct and if the computer still reachable or went offline... Aborting"
    break
    }
}
End{
Write-Host "Cluster Management is completed..."
    }
}


Function Set-EMMDBActivationMoveNow{
    [cmdletbinding()]
    Param(
    [parameter(Mandatory=$true,
                 ValueFromPipeline=$true,
                 Position=0)]
                 $ServerName,
    [parameter(mandatory=$True)][validateset("IntrasiteOnly","Unrestricted","BlockMode")]$ActivationMode,
    [parameter(mandatory=$false)]$TimeoutBeforeManualMove=120,
    [parameter(mandatory=$false)][switch]$SkipValidation
    
    )

    begin{
    $FinalResult=""
    }
    Process{
        Try{
            ##Validation first
            $DBSetting=Get-MailboxServer
            if (@($DBSetting | Where-Object {($_.DatabaseCopyAutoActivationPolicy -notlike "Blocked") -and ($_.name -notlike $PSBoundParameters['ServerName'])}).count -eq 0){
                Write-Warning "There is no available server with an Activation Policy set to Unrestricted or IntrasiteOnly" 
                Write-Warning "Please ensure that there is at least one server available to handle the load..."
                Write-Warning "Try to run Stop-EMMDAGEnabled and set the healthy servers as a ServerInMaintenance." 
                Write-Warning "This will ensure that the server is ready to be in service"
                $DBSetting
                break
                }
                
                if (($PSBoundParameters['ActivationMode'] -like "BlockMode")){
                    Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyActivationDisabledAndMoveNow $true -ErrorAction stop
                    Start-Sleep 1
                    $DatabaseCopyPolicy=Get-MailboxServer $PSBoundParameters['ServerName'] -ErrorAction Stop 
                    Write-Host "Please write down the current Activation policy as it might be needed later" 
                    write-host $DatabaseCopyPolicy.DatabaseCopyAutoActivationPolicy -ForegroundColor DarkRed -BackgroundColor Yellow
                    Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyAutoActivationPolicy Blocked  -ErrorAction Stop

                    if (@(Get-MailboxDatabaseCopyStatus -Server $PSBoundParameters['ServerName'] | Where-Object{$_.Status -eq "Mounted"}).count -eq 0){
                    Write-Host "No Active Database on this server was found... The New DatabaseCopyAutoActivationPolicy is: " -NoNewline 
                    Write-Host (Get-MailboxServer $PSBoundParameters['ServerName']).DatabaseCopyAutoActivationPolicy -ForegroundColor Green 
                    return "No Active Database, Server is ready"
                    }
                    try{
                            Write-host "Mailbox Database migration will start and move all DBs from $($PSBoundParameters['ServerName'])"
                            Write-Host "ReplayQueue Length and Copy Queue length should be zero, if not the script will wait untill all transaction are completed."
                                        $DBOnServer=Get-MailboxDatabaseCopyStatus -Server $PSBoundParameters['ServerName'] -ErrorAction stop| Where-Object{$_.Status -eq "Mounted"}
                                          foreach ($singleDB in $DBOnServer){ # Checking Queue length 
                                            Write-Host "Processing" $($singleDB).DatabaseName -ForegroundColor Green 
                                                $DBOnRemoteServerQL=Get-MailboxDatabase $singleDB.DatabaseName | Get-MailboxDatabaseCopyStatus -ErrorAction Stop | Where-Object {($_.databasename -like $singleDB.DatabaseName) -and ($_.MailboxServer -notlike $PSBoundParameters['ServerName'])}
                                                    if (($DBOnRemoteServerQL.status -contains 'FailedAndSuspended')){
                                                    Write-Host "WARNING: The other copy of this database is not health, failover for this database wont work" -ForegroundColor Red -BackgroundColor White 
                                                    Write-Host "The Database wont move. Before shutting down the server, make sure to have this DB Fixed and moved safely" -ForegroundColor Red -BackgroundColor White 
                                                    Continue
                                                        }


                                                $TotalQueueLength =$(($DBOnRemoteServerQL.copyQueuelength | Measure-Object -Sum).Sum) +$(($DBOnRemoteServerQL.ReplayQueueLength | Measure-Object -Sum).Sum)
                                                    if ($TotalQueueLength -gt 0){
                                                        Write-Host "Some pending Logs are waiting for replay, I will wait till the process is finished"
                                                            do{
                                                                Write-Host "." -NoNewline
                                                                $DBOnRemoteServerQL=Get-MailboxDatabase $singleDB.DatabaseName | Get-MailboxDatabaseCopyStatus -ErrorAction Stop | Where-Object {($_.databasename -like $singleDB.DatabaseName) -and ($_.MailboxServer -notlike $PSBoundParameters['ServerName'])}
                                                                Start-Sleep 1
                                                              }
                                                              While (
                                                              
                                                              $(($DBOnRemoteServerQL.copyQueuelength | Measure-Object -Sum).Sum) +$(($DBOnRemoteServerQL.ReplayQueueLength | Measure-Object -Sum).Sum) -ne 0
                                                              )
    
    
                                                    }
                                                    Else{
                                                        switch($PSBoundParameters.ContainsKey('SkipValidation')){
    
                                                        $true {Move-ActiveMailboxDatabase -Identity $singleDB.DatabaseName -Confirm:$false -ErrorAction Stop -SkipClientExperienceChecks -SkipCpuChecks -SkipMaximumActiveDatabasesChecks -MoveComment "EMM Module"  -SkipMoveSuppressionChecks 
                                                                }
                                                        $false {Move-ActiveMailboxDatabase -Identity $singleDB.DatabaseName -Confirm:$false -ErrorAction Stop 
                                                                }
                                                        }
                                                        Write-Host "Database $($singleDB.DatabaseName) is now hosted on " -NoNewline 
                                                        Write-Host $(Get-MailboxDatabase | Get-MailboxDatabaseCopyStatus | Where-Object {($_.databasename -like $singleDB.DatabaseName) -and ($_.status -like "mounted")}).MailboxServer -ForegroundColor Green
                                                        Start-Sleep -Seconds 1
                                                    }
                                                }
                        }
    
                        Catch [Microsoft.Exchange.Cluster.Replay.AmDbActionWrapperException]{
                        Write-Host "It seems that there still more logs to be shipped, please check the error below and try to re-run the commands after sometime" -ForegroundColor Yellow
                        Write-Host "Or the database has been already activated on the remote server."
                        Write-Host $_.exception.message
                        return "Require review, Please Run Get-MailboxDatabaseCopyStatus and also run the Test-EMMReadiness cmdlet to confirm the readiness"
                        }
                        catch [Microsoft.Exchange.Cluster.Replay.AmDbMoveMoveSuppressedException]{
                        Write-Host "`nIt seems that there are multiple move request for this database" -ForegroundColor Red
                        Write-Host $_.exception.message -ForegroundColor Red
                        Write-Host "To ignore the error and move the database, use the following paramter " -NoNewline -ForegroundColor white
                        Write-Host "-SkipValidation" -ForegroundColor Green
                        }
                        catch{
                        Write-Warning $_.Exception.Message
                        break
                        }
          
                }
                Else{
                Write-Host "Leaving Block Mode"
                
                try{
    
                    Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyAutoActivationPolicy $PSBoundParameters['ActivationMode']  -ErrorAction Stop
                    Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyActivationDisabledAndMoveNow $false  -ErrorAction Stop
                    Start-Sleep 1
                    $FinalResult= (Get-MailboxServer $PSBoundParameters['ServerName']  -ErrorAction Stop) 
                    return $FinalResult.DatabaseCopyAutoActivationPolicy
                    }
                    catch{
                    Write-Host $Error[0]
                    break
                    }
    
                }
    
    
        }
        Catch{
        Write-Host "Failure in Set-EMMDBActivationMoveNow"
        Write-Host $Error[0]
        break
    
        }
    }
        End{
            Write-Host "Activation configuration is completed..."
            }
    }



Function Test-EMMReadiness{
param(
[parameter(Mandatory=$false)][switch]$IgnoreCluster
)

   Process{
   Write-Host "This process will check the server readiness" -ForegroundColor Yellow
   Write-Host "There will be no move or any change to the environment, just a check" -ForegroundColor Yellow 
   $EXServers=Get-ExchangeServer

        AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Testing Exchange Services Ports reachability, Checking Port 80..." -MessageColor Yellow
        ($EXServers).foreach{$Port80Test=Test-NetConnection -ComputerName $_.name -Port 80
            if ($Port80Test.TcpTestSucceeded -like $True){
                Write-Host $($_.name) -ForegroundColor Green -NoNewline;Write-Host " is reachable on Port 80"
                    }
            Else{
                Write-Host $($_.name) -ForegroundColor Red -NoNewline;Write-Host " is NOT reachable on Port 80"
                }
                                    }



        AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Testing Exchange Ports reachability, Checking Port 443..." -MessageColor Yellow
        ($EXServers).foreach{$Port443Test=Test-NetConnection -ComputerName $_.name -Port 443
            if ($Port443Test.TcpTestSucceeded -like $True){
                Write-Host $($_.name) -ForegroundColor Green -NoNewline;Write-Host " is reachable on Port 443"
                    }
            Else{
                Write-Host $($_.name) -ForegroundColor Red -NoNewline;Write-Host " is NOT reachable on Port 443"
                }
                                    }   
                                    
                ######## Certificate Check
        AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking SSL Certificate Validity " -MessageColor Yellow
        $CertificateReport=@()
        ($EXServers).foreach{
                $SrvCert=Get-ExchangeCertificate -Server $_
                $SRVServer=$_
                foreach ($SingleCert in $SrvCert){
                $CNName=$SingleCert.Subject -match "CN=([^,]*)" | out-null
                 $cn = $matches[1]

                    $singleCertRep=[PScustomObject]@{
                        ServerName= $SRVServer
                        CN=$cn
                        SAN=@($SingleCert.CertificateDomains.domain)
                        Issued=$SingleCert.NotBefore
                        Expire=$SingleCert.NotAfter
                        Services=$singlecert.Services
                        ThumpPrint=$SingleCert.Thumbprint
                        }
                        $CertificateReport+=$singleCertRep
                    if ($SingleCert.NotAfter -lt (Get-Date)){Write-Host "$($SingleCert.Thumbprint) has expired" -ForegroundColor Red} 
                    }
            

        }
$CertificateReport | ft ServerName,CN,Expire,Services
        ############## End Certificate Check    
        
        ########### Checking Cluster Configuration
       AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking Cluster Network Settings, Please refere to" -MessageColor Yellow
       Write-host "https://techcommunity.microsoft.com/t5/failover-clustering/tuning-failover-cluster-network-thresholds/ba-p/371834"
       Write-host "SameSubnetThreshold $((get-cluster).SameSubnetThreshold )"
       Write-host "CrossSubnetThreshold $((get-cluster).CrossSubnetThreshold )"
       Write-host "SameSubnetThreshold $((get-cluster).SameSubnetDelay  )"
       Write-host "SameSubnetThreshold $((get-cluster).CrossSubnetDelay  )" 
        
        ######### End Cluster Configuration                     

            AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking HubTransport Server Component" -MessageColor Yellow
            $ServerComp=Get-ExchangeServer | Get-ServerComponentState -Component Hubtransport
       if (!($ServerComp | Where-Object {($_.State -like "Active")})){
            Write-host "You Don't have any additional Node with a Hubtransport State set to Active" -ForegroundColor Red
            $ServerComp
            }
            Else{
              $ServerComp.foreach{
                   if ($_.state -like "Active"){Write-Host "The HubTransport State of $($_.ServerFqdn) is: " -NoNewline; Write-Host "Active" -ForegroundColor Green}
                    Else{
                    Write-Host "WARNING: The HubTransport State of $($_.ServerFqdn) is: " -NoNewline; Write-Host $_.State -ForegroundColor RED}
                    }
            }

            AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking ServerWideOffline Server Component" -MessageColor Yellow
           $ServerCompSWO=Get-ExchangeServer | Get-ServerComponentState -Component ServerWideOffline
       if (!($ServerCompSWO | Where-Object {($_.State -like "Active")})){
            Write-host "You Don't have any additional Node with a ServerWideOffline State set to Active" -ForegroundColor Red
            }
            Else{
              $ServerCompSWO.foreach{
                   if ($_.state -like "Active"){Write-Host "The ServerWideOffline State of $($_.ServerFqdn) is: " -NoNewline; Write-Host "Active" -ForegroundColor Green}
                    Else{
                    Write-Host "WARNING: The ServerWideOffline State of $($_.ServerFqdn) is: " -NoNewline; Write-Host $_.State -ForegroundColor RED}
                    }
            }
                 
                   AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking HighAvailability Server Component" -MessageColor Yellow
           $ServerCompHA=Get-ExchangeServer | Get-ServerComponentState -Component HighAvailability
       if (!($ServerCompHA | Where-Object {($_.State -like "Active")})){
            Write-host "You Don't have any additional Node with a HighAvailability State set to Active" -ForegroundColor Red
            $ServerCompHA 
            }
            Else{
              $ServerCompHA.foreach{
                   if ($_.state -like "Active"){Write-Host "The HighAvailability State of $($_.ServerFqdn) is: " -NoNewline; Write-Host "Active" -ForegroundColor Green}
                    Else{
                    Write-Host "WARNING: The HighAvailability State of $($_.ServerFqdn) is: " -NoNewline; Write-Host $_.State -ForegroundColor RED}
                    }
            }
            switch ($PSBoundParameters.ContainsKey('IgnoreCluster')){
            $true {Write-Host "Skipping Cluster check..." -ForegroundColor Yellow }
            $false {Write-Host "Starting Cluster Check..." -ForegroundColor Yellow
          $Status=Get-Cluster (Get-DatabaseAvailabilityGroup)| Get-ClusterNode
          if (!($Status | Where-Object {($_.state -like 'up')})){
                Write-Host "WARNING: The number of available clusters is not enough, Please resume one node at least" -ForegroundColor Red
                $Status
                }
                Else{
                Write-Host "Active Cluster Nodes are: " -NoNewline ;Write-Host $($Status | Where-Object {$_.state -like "Up"}).count -ForegroundColor Green
                Write-Host "Unstable Cluster Nodes are: " -NoNewline
                $NotUpCluster=@($Status | Where-Object {$_.state -notlike "Up"}).count
                    switch ($NotUpCluster)
                    {
                        '0' {Write-Host "0" -ForegroundColor Green}
                        {$_ -gt 0} {Write-Host $($Status | Where-Object {$_.state -notlike "Up"}).count -ForegroundColor Red}
                        
                    }
                 
                $Status | Where-Object {$_.state -notlike "Up"}
                }
          
           }

           }

         AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Checking Exchange Servers for Mounting policy" -MessageColor Yellow
         $DBSetting=Get-MailboxServer
        if (!($DBSetting | Where-Object {($_.DatabaseCopyAutoActivationPolicy -notlike "Blocked")})){
            Write-Warning "There is no available server with an Mounting Policy set to Unrestricted or IntrasiteOnly"  
            Write-Warning "Please ensure that there is at least one server available to handle the load..."
            $DBSetting | Select-Object name,DatabaseCopyAutoActivationPolicy,DatabaseCopyActivationDisabledAndMoveNow
            }
            Else{
                $DBSetting.ForEach{
                    if ($_.DatabaseCopyAutoActivationPolicy -like "Unrestricted"){Write-Host "Mounting Policy for $($_.Name) is: "-NoNewline; Write-Host "Unrestricted" -ForegroundColor Green} 
                    if ($_.DatabaseCopyAutoActivationPolicy -Like "IntrasiteOnly"){Write-Host "Mounting Policy for $($_.Name) is: "-NoNewline; Write-Host "IntrasiteOnly" -ForegroundColor Yellow}
                    if ($_.DatabaseCopyAutoActivationPolicy -Like "Blocked"){Write-Host "Mounting Policy for $($_.Name) is: "-NoNewline; Write-Host "Blocked" -ForegroundColor Red}
                 }
            }

               AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking Exchange Servers for Activating Policy" -MessageColor White
        if (@($DBSetting | Where-Object {($_.DatabaseCopyActivationDisabledAndMoveNow -notlike $true)}).count -eq 0){
            Write-Warning "There is no available server with an Activation Policy set to Unrestricted or IntrasiteOnly" 
            Write-Warning "Please ensure that there is at least one server available to handle the load..."
            $DBSetting | Select-Object name,DatabaseCopyAutoActivationPolicy,DatabaseCopyActivationDisabledAndMoveNow
            }
            Else{
                $DBSetting.ForEach{
                    if ($_.DatabaseCopyActivationDisabledAndMoveNow -like $False){Write-Host "Activation Policy for $($_.Name) is: "-NoNewline; Write-Host "Can host DB" -ForegroundColor Green} 
                    if ($_.DatabaseCopyActivationDisabledAndMoveNow -Like $true){Write-Host "Activation Policy for $($_.Name) is: "-NoNewline; Write-Host "Not Recommended, True for DatabaseCopyActivationDisabledAndMoveNow" -ForegroundColor red}
                  }
            }
            
         Write-Host "Checking Servicelth:`n"
        
        foreach($singleExServer in $EXServers){
            $ServiceNotRunning=Test-ServiceHealth -Server $singleExServer
            $ServiceNotRunning.ForEach{
                if ($_.ServicesNotRunning.count -gt 0){
                    write-host $singleExServer "has " -NoNewline
                    write-host $_.ServicesNotRunning.count -NoNewline -ForegroundColor Red
                    Write-Host " of failed Service:" -NoNewline
                    Write-Host $_.ServicesNotRunning -ForegroundColor red
                    }
                    Else{
                    write-host $singleExServer $_.Role -NoNewline
                    Write-Host " OK" -ForegroundColor Green
                    }
            
                }
            }

       
        Write-Host "Checking Log size, make sure that there is no log queue or copy queue"
        Write-Host "Only unhealthy result will be displayed"
        (get-ExchangeServer).foreach{ Get-MailboxDatabaseCopyStatus -Server $_.name | where {($_.ContentIndexState -notlike "Healthy") -or
        (($_.Status -notlike "Healthy") -and ($_.Status -notlike "Mounted")) -or
            ($_.CopyQueueLength -gt 0) 
            } | Format-Table Name,Status,ContentIndexState,CopyQueueLength,ReplayQueueLength}
        Write-Host "Testing Replication Health, Only Failed resuly will be displayed"
        get-exchangeserver | Test-ReplicationHealth | where {$_.Result -notlike "Passed"}| Format-Table -AutoSize

    }
    End{
    Write-Host "Process is completed.."
    }

}
Export-ModuleMember Test-EMMReadiness

Write-Host "***************************************************************" -ForegroundColor White
Write-Host "Welcome to EMM (Exchange Maintenance Module)" -ForegroundColor Green -NoNewline
Write-Host " V2.2" -ForegroundColor Yellow
Write-Host "***************************************************************" -ForegroundColor White
Write-Host "Checking for latest version update details and known issues.. " -ForegroundColor Green
try{
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Messageoftheday=(Invoke-WebRequest -Method get -Uri 'https://www.powershellcenter.com/psmessage/emm.txt').content
Write-Host $Messageoftheday -ForegroundColor yellow
}
Catch{
Write-Host "Cannot connect to PowerShellcenter.com, its OK.. the script will continue normally :)" -ForegroundColor Green
}
Write-Host "Please Give me a moment to load Exchange Snapin...." -ForegroundColor Green
Write-host "If loading failed, then start this script from Exchnage Management Shell" -ForegroundColor Yellow
try{
    Import-Module $env:ExchangeInstallPath\bin\RemoteExchange.ps1 -ErrorAction Stop
    Connect-ExchangeServer -Auto -ClientApplication:ManagementShell
    Write-Host "Importing NetTCPIP Module"
    Import-Module NetTCPIP
    Write-Host "Importing Failover Cluster..."
    Import-Module FailoverClusters
 }
catch{
Write-Warning "Ops, something went wrong, are you sure you have Exchange Management Shell installed ?!`n"
Throw $_.exception.message
}
Write-Host "One more tip: Run this Module using RunAsAdministrator " -ForegroundColor Green
Write-Host "If you have any issue or idea request, please feel free and post it as an Issue on my GitHub or keep it a comment on the Module home page"
Write-Host "https://github.com/farismalaeb/Powershell/issues" -ForegroundColor Blue -BackgroundColor White

