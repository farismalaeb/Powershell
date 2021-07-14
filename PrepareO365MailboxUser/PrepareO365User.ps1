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
#Requires -PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn

[cmdletbinding()]
param(
[parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]$SamAccountName,
[parameter(Mandatory=$true)]$EmailDomainToRemove=@()

)
Begin{
    Function Start-PSCMailboxCleanup
    {
        [CmdletBinding()]
        Param
        (
            [Parameter(Mandatory=$true)]$SamAccountName,
            [parameter(Mandatory=$False)]$BadSMTPDomain

        )
      Process
        {
            Try{
        Write-Host ""
        Write-Host "ProcessingReading $($SamAccountName)"
        $xmail=(Get-Mailbox $SamAccountName -ErrorAction stop).EmailAddresses
                Add-Content -Path (Join-Path $PSScriptRoot  "$($SamAccountName).txt") -Value $xmail
                $FixedEmail=($xmail | where {$_ -notlike "*$($EmailDomainToRemove)*"})
                set-mailbox $SamAccountName -EmailAddresses $FixedEmail
                 return $FixedEmail
                }
                catch{
                $_.exception.message
                }


        }
 
    }
   }

   Process
   {
 Try{
Start-PSCMailboxCleanup -SamAccountName $SamAccountName -BadSMTPDomain $EmailDomainToRemove
 }
    catch{
        Write-Host "Ops, I failed... check the error"
        $_.Execption.Message
     }
        
}
