    Set-StrictMode -Version latest 
Function Set-XEMMDBActivationMoveNow{
    [cmdletbinding(DefaultParameterSetName="ActiveOff")]
    Param(
    [parameter(mandatory=$true,
                ValueFromPipeline=$true,
                ParameterSetName="ActiveOff",
                Position=0)]
    [parameter(Mandatory=$true,
               ParameterSetName="ActiveOn",
               ValueFromPipeline=$true,
                Position=0)]
    [parameter(Mandatory=$true,
                ParameterSetName="ActiveOnSingle",
                ValueFromPipeline=$true,
                 Position=0)]
                 $ServerName,
    [parameter(mandatory=$True)][validateset("IntrasiteOnly","Unrestricted","BlockMode")]$ActivationMode,
    [parameter(mandatory=$false,ParameterSetName="ActiveOn")]$TimeoutBeforeManualMove=120,
    [parameter(mandatory=$false)][switch]$SkipValidation
    
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
                
                if (($PSBoundParameters['ActivationMode'] -like "BlockMode")){
                    Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyActivationDisabledAndMoveNow $true -ErrorAction stop
                    sleep 1
                    $DatabaseCopyPolicy=Get-MailboxServer $PSBoundParameters['ServerName'] -ErrorAction Stop 
                    Write-Host "Please write down the current Activation policy as it might be needed later" 
                    write-host $DatabaseCopyPolicy.DatabaseCopyAutoActivationPolicy -ForegroundColor DarkRed -BackgroundColor Yellow
                    Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyAutoActivationPolicy Blocked  -ErrorAction Stop

                    if (@(Get-MailboxDatabaseCopyStatus -Server $PSBoundParameters['ServerName'] | Where{$_.Status -eq "Mounted"}).count -eq 0){
                    Write-Host "No Active Database on this server was found... The New DatabaseCopyAutoActivationPolicy is: " -NoNewline 
                    Write-Host (Get-MailboxServer $PSBoundParameters['ServerName']).DatabaseCopyAutoActivationPolicy -ForegroundColor Green 
                    return "No Active Database, Server is ready"
                    }
                    try{
                            Write-Host "Waiting for Database migration to complete, Timeout for this process is $($PSBoundParameters['TimeoutBeforeManualMove']) Seconds"
                            Write-Host "Exchange will make a basic health and validate other database, this might take sometime..."
                            $i=0
                            Write-Host "EMMEXDAGModule v2 note: Database migration will follow database activation preference instead of moving all databases to a single server." -ForegroundColor Yellow
                            Write-host "Manual migration will start and move all DBs from $($PSBoundParameters['ServerName'])"
                            Write-Host "ReplayQueue Length and Copy Queue length should be zero, if not the script will wait untill all transaction are completed."
                            Do{
                                Write-Host "." -NoNewline
                                $i++
                                sleep 1
                                    if ($i -ge $PSBoundParameters['TimeoutBeforeManualMove']){
                                        Write-Host "The Number of the databases on this node are: "-NoNewline 
                                        $DBOnServer=Get-MailboxDatabaseCopyStatus -Server $PSBoundParameters['ServerName'] -ErrorAction stop| Where{$_.Status -eq "Mounted"}
                                          foreach ($singleDB in $DBOnServer){ # Checking Queue length 
                                            Write-Host "Processing $($singleDB)" -ForegroundColor Green 
                                                $DBOnRemoteServerQL=Get-MailboxDatabase $singleDB.DatabaseName | Get-MailboxDatabaseCopyStatus -ErrorAction Stop | where {($_.databasename -like $singleDB.DatabaseName) -and ($_.MailboxServer -notlike $PSBoundParameters['ServerName'])}
                                                $TotalQueueLength =$(($DBOnRemoteServerQL.copyQueuelength | Measure-Object -Sum).Sum) +$(($DBOnRemoteServerQL.ReplayQueueLength | Measure-Object -Sum).Sum)
                                                    if ($TotalQueueLength -gt 0){
                                                        Write-Host "Some pending Logs are waiting for replay, I will wait till the process is finished"
                                                            do{
                                                                Write-Host "." -NoNewline
                                                                $DBOnRemoteServerQL=Get-MailboxDatabase $singleDB.DatabaseName | Get-MailboxDatabaseCopyStatus -ErrorAction Stop | where {($_.databasename -like $singleDB.DatabaseName) -and ($_.MailboxServer -notlike $PSBoundParameters['ServerName'])}
                                                                sleep 1
                                                              }
                                                              While (
                                                              
                                                              $(($DBOnRemoteServerQL.copyQueuelength | Measure-Object -Sum).Sum) +$(($DBOnRemoteServerQL.ReplayQueueLength | Measure-Object -Sum).Sum) -ne 0
                                                              )
    
    
                                                    }
                                                    Else{
                                                        Write-Host "Processing Database Migration.. Please wait."
                                                        switch($PSBoundParameters.ContainsKey('SkipValidation')){
    
                                                        $true { Write-Host "Moving Databases and Ignoring all possible checks" -ForegroundColor Yellow -BackgroundColor Black
                                                                $MoveDBNow= Move-ActiveMailboxDatabase -Identity $singleDB.DatabaseName -Confirm:$false -ErrorAction Stop -SkipClientExperienceChecks -SkipCpuChecks -SkipMaximumActiveDatabasesChecks -MoveComment "EMM Module"  -SkipMoveSuppressionChecks 
                                                                }
                                                        $false {Write-Host "Moving Databases with default Exchange Database check" -ForegroundColor Yellow 
                                                              
                                                               $MoveDBNow= Move-ActiveMailboxDatabase -Identity $singleDB.DatabaseName -Confirm:$false -ErrorAction Stop 
                                                                }
                                                        }
                                                        Write-Host "Database $($singleDB.DatabaseName) is now hosted on " -NoNewline 
                                                        Write-Host $(Get-MailboxDatabase | Get-MailboxDatabaseCopyStatus | where {($_.databasename -like $singleDB.DatabaseName) -and ($_.status -like "mounted")}) -ForegroundColor Green
                                                        sleep -Seconds 1
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
                        Write-Host $_.exception.message
                        return "Require review, Please Run Get-MailboxDatabaseCopyStatus and also run the Test-EMMReadiness cmdlet to confirm the readiness"
                        }
                        catch{
                        Write-Warning $_.exception.message
                        break
                        }
          
                }
                Else{
                Write-Host "Leaving Block Mode"
                
                try{
    
                    Set-MailboxServer $PSBoundParameters['ServerName'] -DatabaseCopyAutoActivationPolicy $PSBoundParameters['ActivationMode']  -ErrorAction Stop
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


Set-XEMMDBActivationMoveNow -ActivationMode BlockMode -ServerName aud-mail-n2 -TimeoutBeforeManualMove 20 -SkipValidation