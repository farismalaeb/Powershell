Function Get-PSCActiveSession{

    [CmdletBinding()]   
    Param
    (
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Name,
        [parameter(mandatory=$false)][switch]$IgnoreError
        

    )

    Begin
    {
    }
    Process
    {

        Try{
           [System.Collections.ArrayList]$fullList=@()
    $queryresult=query user /server:$($Name) 2> $Null

    if ((!($queryresult) -and (!($PSBoundParameters.ContainsKey('IgnoreError')))) ){Write-host "It Seems there was an issue for $($Name)`n Or there is no active session The Error is $($Error[0])" -ForegroundColor Red}

    Else{
            Foreach ($resultline in ($queryresult | Select-Object -Skip 1)){
                $Parsedline=$resultline.Split(" ",[System.StringSplitOptions]::RemoveEmptyEntries)
                $ComputerList=[PSCustomObject]@{Name=''
                                            Username=''
                                            SessionState=''
                                            SessionID=''
                                            }
                            switch ($resultline)
                            {
                                {$_ -like '*console*'}{
                                        $ComputerList.Name=$Name
                                        $ComputerList.SessionID=$Parsedline[2]
                                        $ComputerList.SessionState="Console"
                                        $ComputerList.Username=$Parsedline[0].Replace(">","")
                                       }
                                {$_ -like '*Disc*'}{
                                        $ComputerList.Name=$Name
                                        $ComputerList.SessionID=$Parsedline[1]
                                        $ComputerList.SessionState="Disconnected"
                                        $ComputerList.Username=$Parsedline[0]
                                        }
                                Default {
                                        $ComputerList.Name=$Name
                                        $ComputerList.SessionID=$Parsedline[2]
                                        $ComputerList.SessionState="Active"
                                        $ComputerList.Username=$Parsedline[0]
                                        }
                                
                        }
                        $fullList.Add($ComputerList) |Out-Null

      

            }
            
   

     }
    return $fullList
    }

    catch{
    Write-Host $_.excption.Message 
        }
    }


    }
Export-ModuleMember Get-PSCActiveSession

Function Start-PSCRemoteLogoff{
   [CmdletBinding(DefaultParameterSetName='AllUsers')]   
    Param
    (
        [Parameter(Mandatory=$True,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Name,
        [Parameter(Mandatory=$false,ParameterSetName="SingleUser")]$TargetUser,
        [parameter(mandatory=$false,ParameterSetName="AllUsers")][switch]$LogoffAll,
        [parameter(mandatory=$false,ParameterSetName="DisconnectedOnly")][switch]$DisconnectedOnly
     

    )
    Begin{

    }

    Process{
    $ActiveSession=Get-PSCActiveSession -name $Name
    if (!( $ActiveSession)){Write-Host "No Active Session found" -ForegroundColor Red
                    return
                    }
    if ($PSBoundParameters.ContainsKey("TargetUser")){       
            Write-Host "Logging Off $($TargetUser) from $($Name)"
            $UserToLogoff= $ActiveSession | Where-Object {$_.Username -like $TargetUser}
            if (!($UserToLogoff)){write-host "$($TargetUser) is not logged in" -ForegroundColor Yellow
                return}
            $LogoffStatus=logoff $UserToLogoff.SessionID /Server:$Name /V
            Write-Host $LogoffStatus -ForegroundColor Green
            
      }

      if ($PSBoundParameters.ContainsKey("DisconnectedOnly")){
        
         $Disconnected=Get-PSCActiveSession -Name $Name | where {$_.SessionState -like "Disconnected"}
        if (!($Disconnected)){return "No Disconnected Sessions"}
        else{
             ForEach($singlesession in $disconnected){logoff $singlesession.SessionID /Server:$Name /V}
             return "Logoff for disconnected session completed"

        }
     }

      if ($PSBoundParameters.ContainsKey("LogoffAll")){
       Write-Host "Logging Off All Users from $($Name)"
        foreach($RemSession in $ActiveSession){
        $RemSession
        $LogoffAllStatus=logoff $RemSession.SessionID /Server:$Name /V
        Write-Host $LogoffAllStatus -ForegroundColor Green
        }
            
    }

    

    }

}

Export-ModuleMember Start-PSCRemoteLogoff 
