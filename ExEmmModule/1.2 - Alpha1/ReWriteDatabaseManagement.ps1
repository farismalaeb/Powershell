Set-StrictMode -Version latest
Function Start-XEMMRedirectMessage{
param(
[parameter(mandatory=$True,ValueFromPipeline=$true,Position=0)]$SourceServer,
[parameter(mandatory=$True)][ValidatePattern("(?=^.{1,254}$)(^(?:(?!\d+\.|-)[a-zA-Z0-9_\-]{1,63}(?<!-)\.?)+(?:[a-zA-Z]{2,})$)")][string]$ToServer
)
        $counter=0
   Write-Host "Redirecting the Queue..."
             Redirect-Message -Server $PSBoundParameters['SourceServer'] -Target $PSBoundParameters['ToServer'] -Confirm:$False -ErrorAction Stop
             Sleep -Seconds 10
             Write-Host "Queue redirection completed..."
             do
             {
               Write-Host "."   -NoNewline
               $QL=(Get-Queue -server aud-mail-n2 | where {($_.DeliveryType -notlike "Shadow*") -and ($_.DeliveryType -notlike "Undefined") }| select Messagecount | Measure-Object -Sum -Property MessageCount).Sum
               if ($ql -eq 0){return "Queue Transfer successfully"}
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
        

$xxx=Start-XEMMRedirectMessage -SourceServer aud-mail-n2 -ToServer aud-mail-n1.adcci.gov.ae 

