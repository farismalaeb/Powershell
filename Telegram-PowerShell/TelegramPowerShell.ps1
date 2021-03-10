[cmdletbinding()]
param(
[parameter(Mandatory=$true)]$Token,
[parameter(Mandatory=$true)]$PassPhrase,
[parameter(Mandatory=$true)]$FirstName,
[parameter(Mandatory=$true)]$LastName,
[parameter(Mandatory=$false)]$AllowedCommands

)
#region Variables
$URL='https://api.telegram.org/bot{0}' -f $Token
$AcceptedSession=""
$LastUnAuthenticatedMessage=""
$lastexecMessageID=""
#endregion Variables

#region Function
Function FixTheStream {
    param(
    $Stream
    )
    Write-Verbose -Message "Fixing the stream, Text is stored in $($env:TMP)\TGPSMessages.txt"
        $FixedResult=@()
        $Stream | Out-File -FilePath (Join-Path $env:TMP -ChildPath "TGPSMessages.txt") -Force
        $ReadAsArray= Get-Content -Path (Join-Path $env:TMP -ChildPath "TGPSMessages.txt") | where {$_.length -gt 0}
        foreach ($line in $ReadAsArray){
            $ArrObj=New-Object psobject
            $ArrObj | Add-Member -MemberType NoteProperty -Name "Line" -Value ($line).tostring()
            $FixedResult +=$ArrObj
        }
        Write-Verbose -Message "Done fixing the message, the return will be $($FixedResult)"
        return $FixedResult


}

Function SendTGMessage{ #Send Message to Telegram Service
    param(
    $Messagetext,
    $ChatID
    )
    Write-Verbose -Message "Preparing to send TG Message" 
    $FixedText=FixTheStream -Stream $Messagetext
        $MessageToSend = New-Object psobject 
        $MessageToSend | Add-Member -MemberType NoteProperty -Name 'chat_id' -Value $ChatID
        $MessageToSend | Add-Member -MemberType NoteProperty -Name 'text' -Value $FixedText.line
        $JsonData=($MessageToSend | ConvertTo-Json)
        Write-Verbose -Message "----------------- Message that will be sent ----------------"
        Write-Verbose -Message $JsonData
        Write-Verbose -Message " ---------------- End of Message ---------------------------"
        Invoke-RestMethod -Method Post -Uri ($URL +'/sendMessage') -Body $JsonData -ContentType "application/json"
        Write-Verbose -Message "Message should be sent"
    }


Function ReadTGMessage{ #Read Incomming message 
    try{
        $inMessage=Invoke-RestMethod -Method Get -Uri ($URL +'/getUpdates') -ErrorAction Stop
        Write-Verbose -Message "Checking for new Messages $($inMessage.result[-1])"
        return $inMessage.result[-1]

    }
    Catch{
        Write-Host $_.exception.message -ForegroundColor red
        return "TGFail"
    }

}

Function IsAuthenticated{ 
param(
    $CheckMessage
)
    Write-Verbose -Message "Checking Authentication Function..."
    if (($messages.message.date -ne $LastUnAuthenticatedMessage) -and ($CheckMessage.message.text -like $PassPhrase) -and ($CheckMessage.message.from.first_name -like $FirstName) -and ($CheckMessage.message.from.last_name -like $LastName) -and ($CheckMessage.message.from.is_bot -like $false)){
    Write-Verbose -Message "Yes yes, Authenticated ...$($messages.message.chat.id)"
    $script:AcceptedSession="Authenticated"
    Write-Host "Auth Accepted..." -ForegroundColor Green
    return $messages.message.chat.id
    }
    Else{
    Write-Host "No Authentication made, or auth failure.." -ForegroundColor Red
    return 0

    }

}



Function CommandShouldBeExecuted {
    Param(
    $cmdlet
    )
    Write-Verbose -Message "Checking if the command is safe ..."
    try{
    if ($cmdlet -like "/disconnect"){
    Write-Host "Bye Bye ..." -ForegroundColor Green
    SendTGMessage -Messagetext "See You.. loging off" -ChatID $messages.message.chat.id
    $script:AcceptedSession=$null
        return 0
        
            }

    if (Test-Path $AllowedCommands){
        $commands=Get-Content -Path $AllowedCommands
        if (($commands |where {$_ -like ($cmdlet.split("")[0])}).count -gt 0) {
        Write-Verbose -Message "Command is safe and can be executed"
            return 1
            }
            Else{
             Write-Verbose -Message "Not Accepted Command.. "
            return 0
            }

        }
    }
    catch{
     Write-Verbose -Message "Allowed list not found.. executing anything is accepted."
    return 1
    }

}
#endregion Function

Write-Host "Script is activated and will require authentication..."
Write-Host "Waiting for Authentication phrase..."
while ($true){
sleep 1
    $messages=ReadTGMessage

    if ($messages -like "TGFail"){
    Write-Host "it seems we got a problem... lets wait for 10 seconds and then try again"
    Write-Host "Maybe you need to check the authentication Key..."
    sleep -Seconds 10
    }
    
     if (!($messages)){
     Write-Host "No data to parse ... will sleep for a while :)"
     }

     Else{

        if ($LastUnAuthenticatedMessage -like $null){
            $LastUnAuthenticatedMessage=$messages.message.date
           }

        if (!($AcceptedSession)){
            $CheckAuthentication=IsAuthenticated -CheckMessage $messages
            }
            Else{
            if (($CheckAuthentication -ne 0) -and ($messages.message.text -notlike $PassPhrase) -and ($messages.message.date -ne $lastexecMessageID)){
             Write-Verbose -Message "I got $($messages.message.text) and MessageID $($messages.message.message_id)"
                    
                    $DoOrDie=CommandShouldBeExecuted -cmdlet $messages.message.text
                    if ($DoOrDie -eq 1){

                        try{
                            $Result=Invoke-Expression($messages.message.text) -ErrorAction Stop
                            Write-Host "The Output of the command was the following" -ForegroundColor Green
                            $Result
                            Write-Host "End of Execution--------------" -ForegroundColor Green
                            SendTGMessage -Messagetext $Result -ChatID $messages.message.chat.id
                        }
                        catch {
                            SendTGMessage -Messagetext ($_.exception.message) -ChatID $messages.message.chat.id
                        }
                        Finally{
                            $lastexecMessageID=$messages.message.date
                        }
                    }
                                
            }
            

        }


        }
}