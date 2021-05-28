<#PSScriptInfo

.VERSION 1.0.1

.GUID 4537a9bd-47b6-45af-86b6-07ba201c80ae

.AUTHOR Faris Malaeb

.PROJECTURI https://www.powershellcenter.com/

.DESCRIPTION 
 This script will remove any SMTP Domain from the users in your on-premises Exchange organization.
 
 Parameters
  [String][Required] EmailDomainToRemove, the DOMAIN only for the email you want to remove, so if the user is assigned an SMTP
           User1@BadinCloud.com, you will need to set the parameter value to badincloud.com only

  [String][NotRequired] ExchangeConnectionURL, the Exchange Powershell URL, usually its http://servername.fqdn/powershell

  [Switch][NotRequired] BackupFirst, you don't need to assign any value, just present the parameter, 
                        it will create a copy of the user configuration before doing any change and dump it in a text

#> 
[cmdletbinding(DefaultParameterSetName="SingleUserMode")]
param(
[parameter(Mandatory=$true,ParameterSetName="email",Position=1)]$EmailDomainToRemove=@(),
[parameter(Mandatory=$False,ParameterSetName="email")]$ExchangeConnectionURL="",
[parameter(Mandatory=$False,ParameterSetName="email")]$OU,
[parameter(Mandatory=$False,ParameterSetName="email")][switch]$BackupFirst



)

function ExchangeConnection{

    if ($ExchangeConnectionURL){
        StartExchangeConnection
        } 

            if (!($ExchangeConnectionURL)){
                Write-Host "Checking if an active exchange session available to use"
                if (Get-PSSession | Where-Object {($_.ConfigurationName -like "microsoft.exchange") -and ($_.State -like "Opened")}){
                    Write-Host "An active session found"
                    write-host "Proceeding with the configuration..."

                }
                    else{
                    throw "Active Exchange Session not found, Please re-run the script and set the ExchangeConnectionURL"
 

                     }
           }
    }

function StartExchangeConnection {
    
     try{
        Write-Host "Connecting to exchange"
        $EXSession=New-PSSession -ConnectionUri $ExchangeConnectionURL -ConfigurationName microsoft.exchange -ErrorAction Stop #-Authentication Default #uncomment if required
        Import-PSSession $EXSession -AllowClobber

        }
    catch{
        Write-Host "Ops, I failed... check the error"
        throw $_.Exception.Message

    }
}




write-host "Connecting and checking exchange connection.. Please wait"
ExchangeConnection
Write-Host "WANRNING:"-NoNewline -ForegroundColor Yellow
Write-Host "THIS POWERSHELL SCRIPT WILL REMOVE " -NoNewline -ForegroundColor Red ; Write-Host $($EmailDomainToRemove).ToUpper() -NoNewline -ForegroundColor Green; Write-Host " FROM ALL USERS IN THE ORGANIZATION... ARE YOU SURE (Y/N)" -ForegroundColor Red
$conf=Read-Host "Please Type Y to continue, or anything else to exit"
if (($conf -like "y") -or ($conf -like "Y")){

if ($OU){ $allEmails= Get-Mailbox -OrganizationalUnit $OU | where {($_.Alias -notlike "*{*}")}}
Else{$allEmails= Get-Mailbox | where {($_.Alias -notlike "*{*}")}}
        foreach ($singlemail in $allEmails){
        
            $xmail=(Get-Mailbox $singlemail.UserPrincipalName).EmailAddresses

                if ($BackupFirst){
                Add-Content -Path (Join-Path $PSScriptRoot "$($singlemail.DisplayName).txt") -Value $xmail
                }

            $FixedEmail=($xmail | where {$_ -notlike "*$($EmailDomainToRemove)*"})
            set-mailbox $singlemail.UserPrincipalName -EmailAddresses $FixedEmail

        }

}