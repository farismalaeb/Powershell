<#
.Synopsis
   Helps in migrating Exchange Distribution group from On-Prem to Exchange Online
.DESCRIPTION
   While migrating to Exchange Online, the distribution group permission such as SendAs and SendOnBehalf dont
   dont get migrated, so this script helps in moving these missing permission
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
.INPUTS
   Inputs to this cmdlet (if any)
.OUTPUTS
   Output from this cmdlet (if any)
.NOTES
   General notes
.COMPONENT
   The component this cmdlet belongs to
.ROLE
   The role this cmdlet belongs to
.FUNCTIONALITY
   The functionality that best describes this cmdlet
#>
[CmdletBinding(HelpUri = 'http://www.powershellcenter.com')]
    Param
    (
        [Parameter(Mandatory=$True)]$OnPremExchangeServer,
        [parameter(mandatory=$true)]
        [ValidateSet("Kerberos","Default","Basic")]$Auth="Default"

    )


Function ConnectToExchangeOnCloud{

    Try{
        Write-Host "Searching for an Active Exchange Online Session..."
        if (((!(Get-PSSession | Where-Object {($_.ComputerName -like "ps.outlook.com") -and ($_.State -like "opened")})) -or (!(get-command get-excmailbox -ErrorAction SilentlyContinue)))) {
        Write-Host "No Active Session found, creating new session"
        $ExOnCred=Get-Credential -Message "Please Type the username and password for Exchange Online" -ErrorAction Stop
        $OnCloudSession=New-PSSession -ConnectionUri 'https://ps.outlook.com/powershell' -Authentication Basic -ConfigurationName microsoft.exchange -AllowRedirection -ErrorAction Stop -Credential $ExOnCred
        $ImportSession=Import-PSSession -Prefix exc -DisableNameChecking -Session $OnCloudSession
        Write-Host "Session Created..." -ForegroundColor Green
        return "Active Session Created" | Out-Null
    }
        Else{
        Write-Host "An Active Session for Exchange Online is already there, Proceeding forward." -ForegroundColor Green
        return "Active Session exist"
        }

    }
 Catch{
    throw $Error[0]
    }
}


Function ConnectToExchangeOnPrem{
param(
[parameter(mandatory=$true)]$OnPremExchangeServer,
[parameter(mandatory=$true)]
[ValidateSet("Kerberos","Default","Basic")]$Authentication="Default"

)

   Try{
        Write-Host "Searching for an Active Exchange On-Premise Session..."
        if (((!(Get-PSSession | Where-Object {($_.ComputerName -like $OnPremExchangeServer) -and ($_.State -like "opened")})) -or (!(get-command get-excMailbox -ErrorAction SilentlyContinue)))) {
        Write-Host "No Active Session found, creating new session"
        $ExOnPremPCred=Get-Credential -Message "Please Type the username and password for Local Exchange" -ErrorAction Stop
        $OnPremSession=New-PSSession -ConnectionUri ("http://$OnPremExchangeServer/powershell") -Authentication $Authentication -ConfigurationName microsoft.exchange -AllowRedirection -ErrorAction Stop -Credential $ExOnPremPCred
        $ImportSession=Import-PSSession -Prefix exp -DisableNameChecking -Session $OnPremSession
        Write-Host "Session Created..." -ForegroundColor Green
        return "Active Session Created" | Out-Null
    }
        Else{
        Write-Host "An Active Session for Local Exchange is already there, Proceeding forward." -ForegroundColor Green
        return "Active Session Created"
        }

    }
 Catch{
    throw $Error[0]
    }
}

ConnectToExchangeOnPrem -OnPremExchangeServer $OnPremExchangeServer -Authentication $Auth
ConnectToExchangeOnCloud

[System.Collections.ArrayList]$ReportResults=@()
Write-Host "Reading Cloud Groups, Please wait..."
$AllCloudDist=Get-excDistributionGroup
Write-Host "Reading OnPrem Groups, Please wait..."
$AllPremDist=Get-expDistributionGroup

$AllPremDist.foreach({
$SendOnBehalf=[pscustomobject]@{OnPremGroupName=''
               OnPremSendOnBehalf=''
               OnPremSendAs=''
               IsSyncedGroup=''
               OnCloudSendAs=''
               OnCloudSendOnBehalf=''
               }

Write-Host "Group Name: $($_.Name)" -ForegroundColor Green
$SendOnBehalf.OnPremGroupName=$_.Name  
$PremOnBehalf=$_.GrantSendOnBehalfTo.foreach{ ($_.Split("/"))[-1]}
$SendOnBehalf.OnPremSendOnBehalf=($PremOnBehalf -join ",")
$SendOnBehalf.OnPremSendAs=((Get-expDistributionGroup $_.name | Get-expADPermission | where {($_.ExtendedRights -like “*Send-As*”)} ).user -join ",")
    if (!([string]::IsNullOrEmpty((Get-excDistributionGroup -Identity $_.name -ErrorAction 'SilentlyContinue')))) {
            $SendOnBehalf.IsSyncedGroup="Yes"
            $SendOnBehalf.OnCloudSendAs=((Get-excRecipientPermission $_.name | where {$_.AccessRights -like "SendAS"}).Trustee -join ",")
            $SendOnBehalf.OnCloudSendOnBehalf=((Get-excDistributionGroup $_.name).GrantSendOnBehalfTo -join ",")
            }
            Else{
                $SendOnBehalf.IsSyncedGroup="No"
            }
            $SendOnBehalf
$ReportResults.Add($SendOnBehalf)})


$css = @"
<style> 
    
   table {
		font-size: 12px;
		border: 0px; 
		font-family: Arial, Helvetica, sans-serif;
	} 
	
    td {
		padding: 4px;
		margin: 0px;
		border: 0;
	}
	
    th {
        background: #395870;
        background: linear-gradient(#49708f, #293f50);
        color: #fff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
	}

    tbody tr:nth-child(even) {
        background: #f0f0f2;
    }
   
   .NotSynced {
        color: #ff0000;
        font-weight: bold;
    }
    
  
    .CloudSynced {

        color: #008000;
        font-weight: bold;
    }

</style>
"@

$HTMLContent=($ReportResults | ConvertTo-Html) -replace '<td>Yes</td>', '<td class="CloudSynced">Yes</td>'
$HTMLContent=$HTMLContent -replace '<td>No</td>', '<td class="NotSynced">No</td>'


ConvertTo-Html -Title "Hotfix" -Body $HTMLContent  -Head $css -PostContent "<p id='CreationDate'>Creation Date: $(Get-Date)</p>" | Out-File (join-path $PSScriptRoot -ChildPath "ExGroupResults.html")
