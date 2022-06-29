<#PSScriptInfo
.VERSION 1.2
.AUTHOR Faris Malaeb
.PROJECTURI https://www.powershellcenter.com/
.DESCRIPTION 
 This Powershell module will Place your Exchange Server DAG in maintenance Mode
 Also you can remove Exchange DAG from Maintenance Mode.
 Available Commands
    Start-EMMDAGEnabled: Set your Exchange Server to be in Maintenance Mode.
    Stop-EMMDAGEnabled: Remove Exchange from maintenanace Mode
    Set-EMMHubTransport: State Stop and Drain the HubTransport Service
    Start-EMMRedirectMessage: Redirect Messages in the Queue to another server FQDN
    Set-EMMClusterConfig: Disable or Enable Cluster Node
    Set-EMMDBActivationMoveNow: Set Exchange MailboxServer to Block mode so it wont accept mailbox activation request
    Test-EMMReadiness: Test the environment for readiness to go in maintenance Mode
   

#> 
Function Check-ScriptReadiness{
param(
$ServerName,
$AltServer
)
        if (((Test-NetConnection -Port 80 -ComputerName $ServerName).TcpTestSucceeded -like $true) -and (Test-NetConnection -Port 80 -ComputerName $AltServer).TcpTestSucceeded -like $true){
        $isadmin=[bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
        switch ($isadmin)
        {
            $true {return 1}
            $false {return 0}
           
        }
       
       }
       Else{
        write-host "Operation failed, please check if the computer and the Alternative Server are reachable" -ForegroundColor Red
        Write-host -Message $Error[0]
        break
       }


}

Function Start-EMMDAGEnabled {
   
    Param(
        [parameter(mandatory=$false,ValueFromPipeline=$true,Position=0)]$ServerForMaintenance,
        [parameter(mandatory=$false)][ValidatePattern("(?=^.{1,254}$)(^(?:(?!\d+\.|-)[a-zA-Z0-9_\-]{1,63}(?<!-)\.?)+(?:[a-zA-Z]{2,})$)")][string]$ReplacementServerFQDN,
        [parameter(Mandatory=$false)][switch]$IgnoreQueue,
        [parameter(Mandatory=$false)][switch]$IgnoreCluster,
        [parameter(Mandatory=$false)][switch]$SkipDatabaseHealthCheck

    )

        Begin{
        $Global:ScriptScope=$True
        AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking Readiness... Please wait" -MessageColor Yellow -ProgressState "Starting" -ProgressPercent 3 
            $ErrorActionPreference="Stop"
            $ReadyToExecute=Check-ScriptReadiness -ServerName $ServerForMaintenance -AltServer $ReplacementServerFQDN
            if ($ReadyToExecute -eq 0){Write-Host "Please Make sure that you execute Powershell as Admin" -ForegroundColor Red
                return
            }
        [hashtable]$ExMainProgress=[ordered]@{}

        }

        Process{
            AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Preparing $($ServerForMaintenance) to be placed in Maintinance Mode" -MessageColor Yellow -ProgressState "Turnning Off HubTransport Activities..."  -ProgressPercent 10 
            $Step1=Set-EMMHubTransportState -Servername $ServerForMaintenance -Status Draining
            AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Will Now Check Queue Service Readiness" -MessageColor Yellow -ProgressState "Turnning Off HubTransport Activities..." -ProgressPercent 15
            switch ($PSBoundParameters.Containskey('IgnoreQueue')){
            $true {write-host "Queue Check... Skipped";$step2="Message Transfer Skipped with Queue Check"}
            $false{$checkQReady=QueueFailure -ServernameToCheck $ServerForMaintenance
                AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Message Redirection Process will Start" -MessageColor Yellow -ProgressState "Redirecting Messages..." -ProgressPercent 25 
                AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "This might take few minuts, Please wait.." -MessageColor Yellow 
                $step2=Start-EMMRedirectMessage -SourceServer $ServerForMaintenance -ToServer $ReplacementServerFQDN -TimeoutinSeconds 0
            }
            }
            sleep 1000
            Switch($PSBoundParameters.Containskey('IgnoreCluster')){
                        $true { AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Skipping Cluster MGMT as user requests." -MessageColor Yellow -ProgressState "Skipping Cluster" -ProgressPercent 50
                                $step3="Skipped"}
                        $false { AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Starting Cluster MGMT." -MessageColor Yellow -ProgressState "Pausing $($ServerForMaintenance) " -ProgressPercent 50
                                $step3=Set-EMMClusterConfig -ClusterNode $ServerForMaintenance -PauseOrResume PauseThisNode}
                    }
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Starting Exchange Database Managment" -MessageColor Yellow -ProgressState "Moving Database to another node" -ProgressPercent 70
            switch ($PSBoundParameters.Containskey('SkipDatabaseHealthCheck')){
            $true {$Step4=Set-EMMDBActivationMoveNow -ServerName $ServerForMaintenance -TargetServerNameForManualMove $ReplacementServerFQDN -BlockMode -TimeoutBeforeManualMove 120 -SkipAllCheckForDBMove}
            $false {$Step4=Set-EMMDBActivationMoveNow -ServerName $ServerForMaintenance -TargetServerNameForManualMove $ReplacementServerFQDN -BlockMode -TimeoutBeforeManualMove 120 }
            }
            
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Switching ServerComponentState ServerWideOffline to Off" -MessageColor Yellow -ProgressState "Updating ServerWideOffline" -ProgressPercent 95
            Set-ServerComponentState $ServerForMaintenance -Component ServerWideOffline -State Inactive -Requester Maintenance
            $step5=get-ServerComponentState $ServerForMaintenance -Component ServerWideOffline
            sleep 3
            Write-Host "All Commands are completed, and below are the result...`n"-ForegroundColor Yellow
            $ExMainProgress.Add("HubTransport Draining",$Step1)
            $ExMainProgress.Add("Queue Length",$step2)
            $ExMainProgress.Add("ClusterNode",$step3)
            $ExMainProgress.Add("Activation Policy",(Get-MailboxServer -Identity $PSBoundParameters['ServerForMaintenance']).DatabaseCopyAutoActivationPolicy)
            $ExMainProgress.Add("ServerWide",$step5.State)

        }
        
        End{
       return $ExMainProgress | ft -AutoSize -Wrap
       $Global:ScriptScope=$False
       $global:FailorNot=0

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
    while($numofline -lt $numberoflines){
        Write-Host ""
        $numofline++
    }
    Write-Host $($PSBoundParameters['MessageToIncludeAtTheEnd']) -ForegroundColor $PSBoundParameters['MessageColor']
    if ($PSBoundParameters['ProgressState']){
    Write-Progress -Activity $PSBoundParameters['MessageToIncludeAtTheEnd'] -Status $PSBoundParameters['ProgressState'] -PercentComplete $PSBoundParameters['ProgressPercent']
    }
    
}



Function QueueFailure{
param(
$ServernameToCheck)
    $global:FailorNot=0
    $timer=0
    Write-Host "Waiting for Queue Refreshing, Please wait, this might take up to 2 Minuts."
        while ($timer -ne 60)
        {
            Trap { 
                Write-Host "." -NoNewline -ForegroundColor Yellow 
                $global:FailorNot=1
                continue
            }
        sleep 1

        if ((Get-Queue -Server $PSBoundParameters['$ServernameToCheck'] -ErrorAction stop | where {$_.DeliveryType -notlike "Shadow*"}) -and ($global:FailorNot -eq 1)){
             
              Return "Queue Refreshed" 
        }

        if ((Get-Queue -Server $PSBoundParameters['$ServernameToCheck'] -ErrorAction stop | where {$_.DeliveryType -notlike "Shadow*"}) -and ($FailorNot -eq 0)){
            Write-Host "." -ForegroundColor Green -NoNewline 
        }

          $timer++

        }
        Return "Not Completed"


}

Function Stop-EMMDAGEnabled {
   
    Param(
        [parameter(mandatory=$false,ValueFromPipeline=$true,Position=0)]$ServerInMaintenance,
        [parameter(Mandatory=$false)][switch]$IgnoreCluster
        
    )

        Begin{
            $ErrorActionPreference="Stop"
            [hashtable]$ExOutMainProgress=[ordered]@{}
        }

        Process{
            Write-Host "Preparing $($ServerInMaintenance) for Activation..." -ForegroundColor Yellow
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Taking the Server Out of Maintenance mode..." -MessageColor Yellow -ProgressState "Enabling ServerWideOffline component" -ProgressPercent 15
            Set-ServerComponentState $ServerInMaintenance -Component ServerWideOffline -State active -Requester Maintenance

            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Configuring cluster if required..." -MessageColor Yellow -ProgressState "Cluster Configuration" -ProgressPercent 35
            switch($PSBoundParameters.Containskey('IgnoreCluster')){
                $true {write-host "Cluster Config are Skipped";$outstep1="Skipped"}
                $false {$outstep1=Set-EMMClusterConfig -ClusterNode $ServerInMaintenance -PauseOrResume ResumeThisNode}
            }
            $outStep2=Set-EMMDBActivationMoveNow -ServerName $ServerInMaintenance -UnrestrictedOrIntrasite Unrestricted 
            AddEmptylines -numberoflines 2 -MessageToIncludeAtTheEnd "Enabling HubTransport Components..." -MessageColor Yellow -ProgressState "Enabling HubTransport..." -ProgressPercent 60
            $outStep3=Set-EMMHubTransportState -Servername $ServerInMaintenance -Status Active
              Write-Host "All should be done, below are the result, Make sure that there is no failure or other issues" -ForegroundColor Yellow
              Write-Host "-------- Result for Activating Server " -NoNewline ;Write-Host "$($ServerInMaintenance) " -ForegroundColor Yellow -NoNewline ;Write-Host " -----------"
              $ExOutMainProgress.Add("ServerWide",(Get-ServerComponentState $ServerInMaintenance -Component ServerWideOffline).State)
              $ExOutMainProgress.Add("ClusterNode",$outstep1)
              $ExOutMainProgress.Add("DB Server Activation",$outStep2)
              $ExOutMainProgress.Add("HubTransport",$outStep3)
          
            
        }
        
        End{
       return $ExOutMainProgress | ft -AutoSize -Wrap
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
  Write-Host "Configuring Hub Transport to be " -NoNewline; Write-Host "$($Status)" -ForegroundColor Green -NoNewline ; Write-Host " For " -NoNewline; Write-Host "$($Servername)" -ForegroundColor Green

    Try
    {    

      if (@((Get-ExchangeServer | Get-ServerComponentState -Component Hubtransport | where {($_.State -like "Active")  -and  ($_.Serverfqdn -notlike "*$Servername*")}).state).Count -eq 0){
            Write-warning "Ops, there are no more servers with a HubTransport state set to Active State in the environment, Please make sure to have at least one"
            break
            }
            $TransportState=@{
            identity=$servername
            Component='HubTransport'
            State=$PSBoundParameters['Status']
            Requester="Maintenance"
            }
       Set-ServerComponentState @TransportState
       sleep -Seconds 2
       $Srvcomstate=(Get-ServerComponentState $servername -Component HubTransport).state
       return $Srvcomstate
      
    }
    catch {
        Write-Warning -Message $Error[0]
        break
    }

    }

    End{
       Write-Host "Configs are completed, Now $($Servername) is set to be :" -NoNewline; write-host (Get-ServerComponentState $servername -Component HubTransport).state -ForegroundColor Green

    }
    

    
}
Export-ModuleMember Set-EMMHubTransportState


Function Start-EMMRedirectMessage{
param(
[parameter(mandatory=$True,ValueFromPipeline=$true,Position=0)]$SourceServer,
[parameter(mandatory=$False,DontShow)][int]$TimeoutinSeconds=180,
[parameter(mandatory=$True)][ValidatePattern("(?=^.{1,254}$)(^(?:(?!\d+\.|-)[a-zA-Z0-9_\-]{1,63}(?<!-)\.?)+(?:[a-zA-Z]{2,})$)")][string]$ToServer
)
        
begin{

if ($Global:ScriptScope -notlike $true){$TimeoutinSeconds=0

} #the TimeoutinSeconds is only usefull when the Start-Emm is used, otherwise it should be disabled.
}
Process{

    
    try {
        $counter=0
        Write-Host "`nRedirecting queued messages from $($SourceServer) to $($ToServer) process has started..."
        if ($TimeoutinSeconds -eq 0){Write-Host "Transferring the message queue, the process will finish once all the queue is transferred..."}
            Else{Write-Host "Transferring the message queue, the process will take $($TimeoutinSeconds) before timeout." 
        Write-Host "If timeout, you can run the command and set a longer TimeOutinSeconds, or wait some time and then run Get-Queue PS Command"}

        Redirect-Message -Server $SourceServer -Target $ToServer -Confirm:$False -ErrorAction Stop
          
        Write-Host "Waiting for the queue to be transfer"
    Do{

        Start-Sleep -Seconds 1 
        $counter++
        switch ($TimeoutinSeconds)
        {
            '0' {}
            {$_ -gt 0} {Write-Host "." -NoNewline}
            }

        #region TimeOut
            if (($Counter -ge $TimeoutinSeconds) -and ($TimeoutinSeconds -ne 0)){
                Write-Host "Process is Timeout"
                Write-Host "Currently there are $((Get-Queue -server $SourceServer | where {$_.DeliveryType -notlike "Shadow*"}| select Messagecount | Measure-Object -Sum -Property MessageCount).Sum) "-NoNewline
                Write-Host "in the queue, the number should be Zero"
                Write-Host "Queue Transfer fail to complete, Maybe a slow connection or very heavy queue pending"
                Write-Host "You can run the command " -NoNewline
                Write-host "Start-EMMRedirectMessage -SourceServer $($SourceServer) -ToServer $($toserver) -TimeoutinSeconds 0" -ForegroundColor Yellow
                if ($Global:ScriptScope -like $True){
                Write-Host "Do you want to continue placing the server in Maintenance Mode or you want to abort the process?" -ForegroundColor Yellow
                $YesNo=Read-Host "Press Y to continue or any other key to abort the process"
                    if ($YesNo -like "Y"){return "Queue Transfer is not completed, But the user accepted it"}
                    else{
                    return "Aborted"
                    }
                    
                  
                        }
                Else{
                return "Aborted"

                }
         #endregion Timeout

                }
                if ($TimeoutinSeconds -eq 0){
                $QLength=(Get-Queue -server $SourceServer  -ErrorAction Ignore | where {$_.DeliveryType -notlike "Shadow*"}| select Messagecount | Measure-Object -Sum -Property MessageCount).Sum
                if ($counter -eq 30){Write-Host "It's OK, I am still waiting for the transfer, this might take up to 2 minutes, Please wait..."}
                if ($counter -eq 60){Write-Host "This is boring, Yes?!, Anyway, let's wait a bit more..."}
                if ($counter -eq 90){Write-Host "Same as you, i am waiting for the Exchange process to complete.."}
                if ($counter -eq 120){Write-Host "Lets get a cup of coffee and come back..."}
                if ($counter -eq 250){Write-Host "Maybe you need to restart the operation again, if you like press CTRL+C and start the command again, or just wait.."}
                Write-Host "The Current Queue size is " -NoNewline
                Write-Host $QLength -ForegroundColor Green
                if ($QLength -eq 0){
                return "All Transfer and OK"
                }

                }
    }
    while (
    (Get-Queue -server $SourceServer -ErrorAction Ignore | where {$_.DeliveryType -notlike "Shadow*"}| select Messagecount | Measure-Object -Sum -Property MessageCount).Sum -ne 0
    )
    }
    Catch [Microsoft.Exchange.Data.Common.LocalizedException]{
    Write-Host "It seems that the server is not reachable or does not exist... please confirm.`n" 
    Write-Host $error[0] -ForegroundColor Red
    return
    }
    Catch{
    Write-Host $Error[0] -ForegroundColor Red
    Write-Host ""
    $FailedYesNo=Read-Host "The Operation Failed, Do you want to continue?"
                   if ($FailedYesNo -like "Y"){return "Operation Failed, But the user accepted it"}
                    else{
                        Break
                        }
            
    }
}
End{
   
    }
}

Export-ModuleMember Start-EMMRedirectMessage


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
          Write-Host "The number of Up Nodes are $(@(($Status | where {$_.state -like 'up'}).State).count)" -ForegroundColor  Yellow

        if ($PSBoundParameters['PauseOrResume'] -like "PauseThisNode"){
                
         
            if (@($Status | where {($_.state -like 'up') -and ($_.name -notlike $PSBoundParameters['ClusterNode'])}).count -eq 0){
                Write-Host "WARNING: The number of available clusters is not enough, Please stop and resume one node at least" -ForegroundColor Red
                $Status | select Name,State,Cluster
                break
                }

            if (($Status | where{$_.name -like $PSBoundParameters['ClusterNode']}).State -Like "Paused"){
                Write-Host "The node is already disabled...Nothing to do in this step"
                return "Node is Already Paused"
            }
             $clsstate=Suspend-ClusterNode -Name $PSBoundParameters['ClusterNode'] -Cluster (Get-DatabaseAvailabilityGroup) -ErrorAction Stop
                Sleep -Seconds 2
                return $clsstate.State
               }
               ## Resume Cluster node
         if ($PSBoundParameters['PauseOrResume'] -like "ResumeThisNode"){
          if (($Status | where{$_.name -like $PSBoundParameters['ClusterNode']}).State -Like "Up"){
                Write-Host "Node already Up...Nothing to do in this step"
                return "Node is Already Up"
            }
                $clsresumestate=Resume-ClusterNode -Name $PSBoundParameters['ClusterNode'] -Cluster (Get-DatabaseAvailabilityGroup) -ErrorAction Stop
                Sleep -Seconds 2
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
Export-ModuleMember Set-EMMClusterConfig 

Function Set-EMMDBActivationMoveNow{
[cmdletbinding(DefaultParameterSetName="ActiveOff")]
Param(
[parameter(mandatory=$true,
            ValueFromPipeline=$true,
            ParameterSetName="ActiveOff",
            Position=0)]
[parameter(Mandatory=$true,
           ParameterSetName="ActiveOn",
           ValueFromPipeline=$true,
            Position=0)] $ServerName,
[parameter(mandatory=$true,ParameterSetName="ActiveOn")]$TargetServerNameForManualMove,
[parameter(mandatory=$false,ParameterSetName="ActiveOn")][switch]$BlockMode=$true,
[parameter(mandatory=$True,ParameterSetName="ActiveOff")][validateset("IntrasiteOnly","Unrestricted")]$UnrestrictedOrIntrasite,
[parameter(mandatory=$false,ParameterSetName="ActiveOn")]$TimeoutBeforeManualMove=120,
[parameter(mandatory=$false,ParameterSetName="ActiveOn")][switch]$SkipAllCheckForDBMove


)

begin{
$FinalResult=""
}
Process{
    Try{
        ##Validation first
        $DBSetting=Get-MailboxServer
        if (@($DBSetting | where {($_.DatabaseCopyAutoActivationPolicy -notlike "Blocked") -and ($_.name -notlike $PSBoundParameters['ServerName'])}).count -eq 0){
            Write-Warning "There is no available server with an Activation Policy set to Unrestricted or IntrasiteOnly" 
            Write-Warning "Please ensure that there is at least one server available to handle the load..."
            $DBSetting
            break
            }
            
            if (($PSBoundParameters.ContainsKey('BlockMode')) -and  $PsCmdlet.ParameterSetName -eq "ActiveOn"){
                Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyActivationDisabledAndMoveNow $true -ErrorAction stop
                sleep 1
                $DatabaseCopyPolicy=Get-MailboxServer $PSBoundParameters['ServerName']  -ErrorAction Stop | Select name,DatabaseCopyActivationDisabledAndMoveNow,DatabaseCopyAutoActivationPolicy
                Write-Host "Please write down the current Activation policy as it might be needed later" 
                write-host $DatabaseCopyPolicy.DatabaseCopyAutoActivationPolicy -ForegroundColor DarkRed -BackgroundColor Yellow
                Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyAutoActivationPolicy Blocked  -ErrorAction Stop
                if (@(Get-MailboxDatabaseCopyStatus -Server $PSBoundParameters['ServerName'] | Where{$_.Status -eq "Mounted"}).count -eq 0){
                Write-Host "No Active Database on this server was found... The New DatabaseCopyAutoActivationPolicy is: " -NoNewline 
                Write-Host (Get-MailboxServer $PSBoundParameters['ServerName'] | Select name,DatabaseCopyAutoActivationPolicy ).DatabaseCopyAutoActivationPolicy -ForegroundColor Green 
                return "No Active Database, Server is ready"
                }
                try{
                        Write-Host "Waiting for Database migration to complete, Timeout for this process is $($PSBoundParameters['TimeoutBeforeManualMove']) Seconds"
                        $i=0
                        Do{
                            Write-Host "." -NoNewline
                            $i++
                            sleep 1
                                if ($i -ge $PSBoundParameters['TimeoutBeforeManualMove']){
                                    Write-Host "The Number of the databases on this node are: "-NoNewline 
                                    $DBOnServer=Get-MailboxDatabaseCopyStatus -Server $PSBoundParameters['ServerName'] -ErrorAction stop| Where{$_.Status -eq "Mounted"}
                                    Write-host "Manual migration will start and move all DBs from $($ServerName) to $($TargetServerNameForManualMove)"
                                    Write-Host "The Value should be Zero"
                                        foreach ($singleDB in $DBOnServer){
                                        Write-Host $singleDB -ForegroundColor Green ##Delete
                                            $DBOnRemoteServerQL=Get-MailboxDatabaseCopyStatus -Server $TargetServerNameForManualMove -ErrorAction Stop | where {$_.databasename -like $singleDB.DatabaseName}
                                            Write-Host "Database Name: $($DBOnRemoteServerQL.DatabaseName)"
                                            Write-Host "CopyQueue: $($DBOnRemoteServerQL.CopyQueueLength)"
                                            Write-Host "ReplayQueue: $($DBOnRemoteServerQL.ReplayQueueLength)`n"
                                                if (($DBOnRemoteServerQL.CopyQueueLength) -or ($DBOnRemoteServerQL.ReplayQueueLength) -gt 0){
                                                    Write-Host "Some pending Logs are waiting for replay, I will wait till the process is finished"
                                                        do{
                                                            Write-Host "." -NoNewline
                                                            sleep 1
                                                          }
                                                          While (
                                                          ((($DBOnRemoteServerQL.CopyQueueLength) -and ($DBOnRemoteServerQL.ReplayQueueLength)) -ne 0)
                                                          )


                                                }
                                                Else{
                                                    Write-Host "Processing Database Migration.. Please wait."
                                                    switch($PSBoundParameters['SkipAllCheckForDBMove']){

                                                    $true { Write-Host "Moving Databases and Ignoring all possible checks" -ForegroundColor Yellow -BackgroundColor Black
                                                           $MoveDBNow= Move-ActiveMailboxDatabase -Identity $singleDB.DatabaseName -ActivateOnServer $PSBoundParameters['TargetServerNameForManualMove']  -Confirm:$false -ErrorAction Stop -SkipAllChecks 
                                                            }
                                                    $false {Write-Host "Moving Databases with default Exchange Database check" -ForegroundColor Yellow 
                                                           $MoveDBNow= Move-ActiveMailboxDatabase -Identity $singleDB.DatabaseName -ActivateOnServer $PSBoundParameters['TargetServerNameForManualMove']  -Confirm:$false -ErrorAction Stop 
                                                            }
                                                    }
                                                    
                                                    sleep -Seconds 2
                                                }
                                            }                                  


                                    }

                        }
                        while(
                            @(Get-MailboxDatabaseCopyStatus -Server $PSBoundParameters['ServerName']  -ErrorAction Stop | Where{$_.Status -eq "Mounted"}).count -ne 0
                        )
                        
                    }

                    Catch [Microsoft.Exchange.Cluster.Replay.AmDbActionWrapperException]{
                    Write-Host "It seems that there still more logs to be shipped, please check the error below and try to re-run the commands after sometime" -ForegroundColor Yellow
                    Write-Host "Or the database has been already activated on the remote server."
                    Write-Host "Set-EMMDBActivationMoveNow -ServerName $($ServerName) -TargetServerName $($TargetServerNameForManualMove) -Blocked -timeout 200"
                    Write-Host $_.exception.message
                    return "Require review, Please Run Get-MailboxDatabaseCopyStatus"
                    }
                    catch{
                    Write-Warning $Error[0]
                    break
                    }
      
            }
            Else{
            Write-Host "Leaving Block Mode"
            
            try{

                Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyAutoActivationPolicy $PSBoundParameters['UnrestrictedOrIntrasite']  -ErrorAction Stop
                Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyActivationDisabledAndMoveNow $false  -ErrorAction Stop
                sleep 1
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

Export-ModuleMember Set-EMMDBActivationMoveNow

Function Test-EMMReadiness{
param(
[parameter(mandatory=$True,ValueFromPipeline=$true,Position=0)]$SourceServer,
[parameter(Mandatory=$false)][switch]$IgnoreCluster
)

   Process{
   Write-Host "This process will check the server readiness"
   Write-Host "There will be no move or any change to the environment, just a check"
   
    Test-Connection -ComputerName $SourceServer -ErrorAction stop -Count 1
       AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Testing Exchange Ports reachability, Checking Port 80..." -MessageColor White
        (Get-ExchangeServer).foreach{$Port80Test=Test-NetConnection -ComputerName $_.name -Port 80
            if ($Port80Test.TcpTestSucceeded -like $True){
                Write-Host $($_.name) -ForegroundColor Green -NoNewline;Write-Host " is reachable on Port 80"
                    }
            Else{
                Write-Host $($_.name) -ForegroundColor Red -NoNewline;Write-Host " is NOT reachable on Port 80"
                }
                                    }
        
        AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Testing Exchange Ports reachability, Checking Port 443..." -MessageColor White
        (Get-ExchangeServer).foreach{$Port443Test=Test-NetConnection -ComputerName $_.name -Port 443
            if ($Port443Test.TcpTestSucceeded -like $True){
                Write-Host $($_.name) -ForegroundColor Green -NoNewline;Write-Host " is reachable on Port 443"
                    }
            Else{
                Write-Host $($_.name) -ForegroundColor Red -NoNewline;Write-Host " is NOT reachable on Port 443"
                }
                                    }

            AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking HubTransport Server Component" -MessageColor White
            $ServerComp=Get-ExchangeServer | Get-ServerComponentState -Component Hubtransport
       if (!($ServerComp | where {($_.State -like "Active")  -and  ($_.Serverfqdn -notlike "*$SourceServer*")})){
            Write-host "You Don't have any additional Node with a Hubtransport State set to Active" -ForegroundColor Red
            Get-ExchangeServer | Get-ServerComponentState -Component Hubtransport
            }
            Else{
              $ServerComp.foreach{
                   if ($_.state -like "Active"){Write-Host "The HubTransport State of $($_.ServerFqdn) is: " -NoNewline; Write-Host "Active" -ForegroundColor Green}
                    Else{
                    Write-Host "The HubTransport State of $($_.ServerFqdn) is: " -NoNewline; Write-Host $_.State -ForegroundColor RED}
                    }
            }

            AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking ServerWideOffline Server Component" -MessageColor White
           $ServerCompSWO=Get-ExchangeServer | Get-ServerComponentState -Component ServerWideOffline
       if (!($ServerCompSWO | where {($_.State -like "Active")  -and  ($_.Serverfqdn -notlike "*$SourceServer*")})){
            Write-host "You Don't have any additional Node with a ServerWideOffline State set to Active" -ForegroundColor Red
            Get-ExchangeServer | Get-ServerComponentState -Component ServerWideOffline
            }
            Else{
              $ServerCompSWO.foreach{
                   if ($_.state -like "Active"){Write-Host "The ServerWideOffline State of $($_.ServerFqdn) is: " -NoNewline; Write-Host "Active" -ForegroundColor Green}
                    Else{
                    Write-Host "The ServerWideOffline State of $($_.ServerFqdn) is: " -NoNewline; Write-Host $_.State -ForegroundColor RED}
                    }
            }

                   AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking HighAvailability Server Component" -MessageColor White
           $ServerCompHA=Get-ExchangeServer | Get-ServerComponentState -Component HighAvailability
       if (!($ServerCompHA | where {($_.State -like "Active")  -and  ($_.Serverfqdn -notlike "*$SourceServer*")})){
            Write-host "You Don't have any additional Node with a HighAvailability State set to Active" -ForegroundColor Red
            Get-ExchangeServer | Get-ServerComponentState -Component HighAvailability
            }
            Else{
              $ServerCompHA.foreach{
                   if ($_.state -like "Active"){Write-Host "The HighAvailability State of $($_.ServerFqdn) is: " -NoNewline; Write-Host "Active" -ForegroundColor Green}
                    Else{
                    Write-Host "The HighAvailability State of $($_.ServerFqdn) is: " -NoNewline; Write-Host $_.State -ForegroundColor RED}
                    }
            }
            switch ($PSBoundParameters["IgnoreCluster"]){
            $true {Write-Host "Skipping Cluster check..." -ForegroundColor Yellow }
            $false {Write-Host "Starting Cluster Check..." -ForegroundColor Yellow}
            }

        if (!($PSBoundParameters["IgnoreCluster"])){
          $Status=Get-Cluster (Get-DatabaseAvailabilityGroup)| Get-ClusterNode
          if (!($Status | where {($_.state -like 'up') -and ($_.name -notlike $SourceServer)})){
                Write-Host "WARNING: The number of available clusters is not enough, Please stop and resume one node at least" -ForegroundColor Red
                $Status
                }
                Else{
                Write-Host "Active Cluster Nodes are: " -NoNewline ;Write-Host $($Status | where {$_.state -like "Up"}).count -ForegroundColor Green
                Write-Host "Unstable Cluster Nodes are: " -NoNewline
                $NotUpCluster=@($Status | where {$_.state -notlike "Up"}).count
                    switch ($NotUpCluster)
                    {
                        '0' {Write-Host "0" -ForegroundColor Green}
                        {$_ -gt 0} {Write-Host $($Status | where {$_.state -notlike "Up"}).count -ForegroundColor Red}
                        
                    }
                 
                $Status | where {$_.state -notlike "Up"}
                }
           }
                 AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking Exchange Servers for Mounting policy" -MessageColor White
        $DBSetting=Get-MailboxServer
        if (!($DBSetting | where {($_.DatabaseCopyAutoActivationPolicy -notlike "Blocked") -and ($_.name -notlike $SourceServer)})){
            Write-Warning "There is no available server with an Mounting Policy set to Unrestricted or IntrasiteOnly"  
            Write-Warning "Please ensure that there is at least one server available to handle the load..."
            $DBSetting | select name,DatabaseCopyAutoActivationPolicy,DatabaseCopyActivationDisabledAndMoveNow
            }
            Else{
                $DBSetting.ForEach{
                    if ($_.DatabaseCopyAutoActivationPolicy -like "Unrestricted"){Write-Host "Mounting Policy for $($_.Name) is: "-NoNewline; Write-Host "Unrestricted" -ForegroundColor Green} 
                    if ($_.DatabaseCopyAutoActivationPolicy -Like "IntrasiteOnly"){Write-Host "Mounting Policy for $($_.Name) is: "-NoNewline; Write-Host "IntrasiteOnly" -ForegroundColor Yellow}
                    if ($_.DatabaseCopyAutoActivationPolicy -Like "Blocked"){Write-Host "Mounting Policy for $($_.Name) is: "-NoNewline; Write-Host "Blocked" -ForegroundColor Red}
                }
            }

               AddEmptylines -numberoflines 1 -MessageToIncludeAtTheEnd "Checking Exchange Servers for Activating Policy" -MessageColor White
        if (@($DBSetting | where {($_.DatabaseCopyActivationDisabledAndMoveNow -notlike $true) -and ($_.name -notlike $SourceServer)}).count -eq 0){
            Write-Warning "There is no available server with an Activation Policy set to Unrestricted or IntrasiteOnly" 
            Write-Warning "Please ensure that there is at least one server available to handle the load..."
            $DBSetting | select name,DatabaseCopyAutoActivationPolicy,DatabaseCopyActivationDisabledAndMoveNow
            }
            Else{
                $DBSetting.ForEach{
                    if ($_.DatabaseCopyActivationDisabledAndMoveNow -like $False){Write-Host "Activation Policy for $($_.Name) is: "-NoNewline; Write-Host "Can host DB" -ForegroundColor Green} 
                    if ($_.DatabaseCopyActivationDisabledAndMoveNow -Like $true){Write-Host "Activation Policy for $($_.Name) is: "-NoNewline; Write-Host "Not Recommended, True for DatabaseCopyActivationDisabledAndMoveNow" -ForegroundColor red}
                  }
            }
            
         Write-Host "Checking Servicelth:`n"
        
        $EXServers=get-exchangeserver
        $EXServiceReport=@()
        foreach($singleExServer in $EXServers){
            $ServiceReport=[PScustomObject]@{
            ServerName=''
            FailedService=''
            RoleName=''
            }
            $ServiceNotRunning=Test-ServiceHealth -Server $singleExServer
            $ServiceNotRunning.ForEach{
                if ($_.ServicesNotRunning.count -gt 0){
                    write-host $singleExServer "has " -NoNewline
                    write-host $_.ServicesNotRunning.count -NoNewline -ForegroundColor Red
                    Write-Host " of failed Service:" -NoNewline
                    Write-Host $_.ServicesNotRunning -ForegroundColor Green
                    }
                    Else{
                    write-host $singleExServer $_.Role "is OK" 
                    }
            
                }
            }

       
        Write-Host "Checking Log size, make sure that there is no log queue or copy queue"
        (get-ExchangeServer).foreach{ Get-MailboxDatabaseCopyStatus -Server $_.name | ft Name,Status,ContentIndexState,CopyQueueLength,ReplayQueueLength}
        Write-Host "Testing Replication Health"
        get-exchangeserver | Test-ReplicationHealth | ft -AutoSize


    }
    End{
    Write-Host "Process is completed.."
    }

}
Export-ModuleMember Test-EMMReadiness

Write-Host "Welcome to EMM (Exchange Maintenance Module) 1.2 - Beta" -ForegroundColor Green
Write-Host "Please Give me a moment to load Exchange Snapin...." -ForegroundColor Green
Write-Host "One more tip: Run this Module using RunAsAdministrator " -ForegroundColor Green
Write-Host "If you unload the EmmExDAGModule Module using Remove-Module cmdlet, you need to close the PowerShell Window and start it again" -ForegroundColor Yellow
Write-Host "This is due to an issue with Microsoft Snapin." -ForegroundColor Yellow
Write-Host "If you have any issue, please feel free and post it as an Issue on my GitHub"
Write-Host "https://github.com/farismalaeb/Powershell/issues" -ForegroundColor Blue -BackgroundColor White



try{
    if ((Get-PSSnapin).Name -notcontains 'microsoft.exchange.management.powershell.snapin'){
        Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction SilentlyContinue
       }
 }
catch{
Write-Warning "Ops, something went wrong, are you sure you have Exchange Powershell Snapin installed ?!`n"
$_.exception.message
}


#Start-EMMDAGEnabled -ServerForMaintenance aud-mail-n2 -ReplacementServerFQDN aud-mail-n1.adcci.gov.ae 