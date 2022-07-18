 <#
    .SYNOPSIS
        This script help you in planning the migration of users from 1 DB to other smaller database.
    .DESCRIPTION
        If you have a large Exchange Database and want to move the users to other database for load distribution, this script will help you in
        planning such migration as it will give you an idea about how many users should be migrated to a single database and how many database required, which can be controlled by parameter
    .PARAMETER $DatabaseName
        $DatabaseName: Required, The Exchange Database Name, as you can get it using Get-Mailboxdatabase

    .PARAMETER $OutputFolder
        $OutputFolder: Required, The Path to a Folder, NOT a file where the script will write the result to.

    .PARAMETER $RequireDBSizeInGB
         $RequireDBSizeInGB: How many GB of information the new database should hold, you can set this to any number above 50.

    .PARAMETER $MaxMBxPerDB
        $MaxMBxPerDB: Not Required, if you want to set a number of users per-Mailbox database, then you can use this parameter, default value is 50000, but you can limit the number 
        per mailbox database to be 100 or whatever as long as the value is above 10.

    .PARAMETER $EXMBxArchiveLog
        $EXMBxArchiveLog: Not Required, Type is Switch, so you only add it if you need it, This switch will enable the script to get similar list but for primary mailbox with its Archive mailbox.
        Note that enabling this option might significantly increase the execution time for the script, as the script will need to search all your exchange archive mailboxes for any
        mailbox archive located in the required database.

    .PARAMETER $MgmtPSFullUri
        $MgmtPSFullUri: Required, The URI to connect to MGMT Powershell URI to initial the session, usually its https://Exchange_Name_Space_URL/powershell ,or maybe http://servername_FQDN/Powershell
        You can find the URI through the following powershell command 
    (Get-PowerShellVirtualDirectory -Server MyServerName).InternalUrl.AbsoluteUri

    .OUTPUTS
       *************************Report********************
            Number of DB Required: XX
            Number of Archive DB required is XX
            *************************************
            Number of Mailbox on each Proposed Database

            Count : XX
            Sum   : XX

            *************************************
            Number of Archive Mailbox on each Proposed Database

            Count : XX
            Sum   : XX
         --------------------------
    .EXAMPLE
        .\New-EXuserDBMigration.ps1 -DatabaseName EXDatabaseName -OutputFolder C:\MyFolder -RequireDBSizeInGB 100 -MgmtPSFullUri "http://myserver.FQDN/powershell" -EXMBxArchiveLog
       
   .NOTES
        Feel free and let me know if you got any comment by sending me an email to farisnt@gmail.com
       
        
    #>


[cmdletbinding()]
param(
[parameter(mandatory=$true)]$DatabaseName,
[parameter(mandatory=$true)]$OutputFolder,
[parameter(mandatory=$true)]$RequireDBSizeInGB,
[parameter(mandatory=$true)]$MgmtPSFullUri,
[parameter(mandatory=$false)][int]$MaxMBxPerDB=50000,
[parameter(mandatory=$false)][switch]$EXMBxArchiveLog=$false

)

Function Get-ExDatabaseusage{
[cmdletbinding()]
    param(
        [parameter(Mandatory=$true)]$DBName,
        [parameter(mandatory=$false)]$RequiredDBSize
        
       
)
$UsersResults=@()
[System.Collections.ArrayList]$ExchCmdLine=@()
[System.Collections.ArrayList]$ExchArchiveCmdLine=@()
[System.Collections.ArrayList]$ExchArchiveCmdLine=@()
$ExCMDWithArchive=""
        Write-Host "Getting users information, this might take few Minuts to complete... Please wait" -ForegroundColor Yellow
        Write-Host "Maybe during this we can check your facebook or take a coffee break :)" -ForegroundColor Yellow
        Write-Host "The process depend on the hardware and the speed of Exchange server response"-ForegroundColor Yellow

        $ReadMailboxFromDB=get-mailbox -Database $DBName
        foreach ($singleMailbox in $ReadMailboxFromDB){
        Write-Host "Getting " -NoNewline
        Write-Host $($singleMailbox) -NoNewline -ForegroundColor Green 
        Write-Host " Information..."
        $ExchCmdLine.Add(($singleMailbox.PrimarySmtpAddress | Get-MailboxStatistics |select DisplayName,TotalItemSize, @{N="EmailAddress";E={$singleMailbox.PrimarySmtpAddress}})) |Out-Null
        }

        if ($EXMBxArchiveLog){ 
       
        Write-Host "Enabling EXMBxArchiveLog, will increase the time the script will take to complete, so please wait..." -ForegroundColor Green
        Write-Host "Searching for Archive mailboxes in the required database..." -ForegroundColor Green
            $ReadMailboxFromDBWithArchive=get-mailbox 
            foreach ($singleMailboxwithArc in $ReadMailboxFromDBWithArchive){
                Write-Host "Getting Archive Info for " -NoNewline
                Write-Host $singleMailboxwithArc -NoNewline -ForegroundColor red
                Write-Host " if its available..."
                $ExCMDWithArchive=$singleMailboxwithArc.PrimarySmtpAddress | Get-MailboxStatistics -Archive -ErrorAction silentlycontinue|Where {$_.databasename -like $DBName} |select DisplayName,TotalItemSize, @{N="EmailAddress";E={$singleMailboxwithArc.PrimarySmtpAddress}}

                if ($ExCMDWithArchive -notlike $null){
                $ExchArchiveCmdLine.Add(($ExCMDWithArchive | where {$_.displayname -notlike $null})) |Out-Null
                
                }
        
           }
        }
        
    #### Get Value for TotalItemSize,prepare the format and convert it to Int
    
        $UsersResults=Prepare-thelist -UsersList $ExchCmdLine
    
    if ($ExchArchiveCmdLine){
         $ExchArchiveCmdLine=Prepare-thelist -UsersList $ExchArchiveCmdLine
         return $UsersResults,$ExchArchiveCmdLine
        }
  
      
return $UsersResults         


}

function Prepare-thelist {
[cmdletbinding()]
param(
[parameter(mandatory=$true)]$UsersList
)
$parsedResult=@()
Foreach ($singlemb in $UsersList){
        
        $formatedusers=New-Object PSObject 
        $formatedusers | Add-Member -NotePropertyName "User" -NotePropertyValue $singlemb.DisplayName
        [string]$Strval1=($singlemb.TotalItemSize.Value)
        $formatedusers | Add-Member -NotePropertyName "MailboxGB" -NotePropertyValue ([math]::Round(  ([int64](($Strval1.Substring($Strval1.IndexOf("(")+1)).Split(" ")[0]).Replace(",","")/1GB),3))
        $formatedusers | Add-Member -NotePropertyName "EmailAddress" -NotePropertyValue $singlemb.EmailAddress
        $parsedResult+=$formatedusers
        
}
        return $parsedResult
}
function Prepare-MyDBLog {
[cmdletbinding()]
param(
[parameter(mandatory=$true)]$UsersList,
[parameter(mandatory=$true)][int]$RequireDBSizeInGB,
[parameter(mandatory=$false)][int]$MaxMBxPerDB=50000

)

$Databases=@()
$i=1
$TotalNewDBSize=0
    foreach ($SingleUser in $UsersList){
    $databasename=New-Object psobject
    $databasename | Add-Member -NotePropertyName "DBName" -NotePropertyValue ""
    $databasename | Add-Member -NotePropertyName "UserMBX" -NotePropertyValue ""
    $databasename | Add-Member -NotePropertyName "UserMBXSize" -NotePropertyValue ""
    $databasename | Add-Member -NotePropertyName "EmailAddress" -NotePropertyValue ""
        
        if (($Databases| where {$_.DBName -match $i}).count -ge $MaxMBxPerDB){
            $TotalNewDBSize=$RequireDBSizeInGB +1
        }

           if (($SingleUser.MailboxGB + $TotalNewDBSize)-gt $RequireDBSizeInGB){
            $i++
            $TotalNewDBSize=0
           }

       $databasename.DBName ="$i"
       $databasename.UserMBX =$SingleUser.User
       $databasename.UserMBXSize =$SingleUser.MailboxGB
       $TotalNewDBSize=$TotalNewDBSize+$SingleUser.MailboxGB
       $databasename.Emailaddress=$SingleUser.EmailAddress
       $Databases+=$databasename
    }
return $Databases

}
$ErrorActionPreference="stop"
######Validation of Parameters ########
    try{

        Write-Host "Checking Parameter...Please wait"
        Write-Host "connecting to Exchange Server... Please wait" -ForegroundColor Yellow
            if (!(Get-PSSession | where {($_.ConfigurationName -like "microsoft.exchange") -and ($_.State -like "Opened")})){
            $ExchangeSession=New-PSSession -ConnectionUri $MgmtPSFullUri -ConfigurationName microsoft.exchange -ErrorAction Stop -AllowClobber
            Import-PSSession $ExchangeSession
            Write-Host "Connection is established and will start getting the result.. please wait"
            }

        Write-Host "Checking Database name...$($DatabaseName)"
        Get-MailboxDatabase -Identity  $DatabaseName -ErrorAction stop
        Write-Host ""
        Write-Host "Testing Output Folder"
        $temppath=Join-Path $OutputFolder -ChildPath  "tmpwrite.tmp"
        Add-Content -Path $temppath -Value "Writing test value"
        if ($RequireDBSizeInGB -lt 50){Write-Host "RequireDBSizeInGB should be bigger than 50"; return}
        if ($MaxMBxPerDB -lt 10){Write-Host "MaxBMxPerDB should be higher than 10"; return}
    }
    catch{
    Write-Host $_.exception.message -ForegroundColor Red
    return
    }



Write-Host "Validation is completed, lets start the fun :)" 
if (!($EXMBxArchiveLog)){
$AllUsersFromDB=Get-ExDatabaseusage -DBName $DatabaseName | Sort-Object MailboxGB
$TotalDBs=Prepare-MyDBLog -UsersList $AllUsersFromDB -RequireDBSizeInGB $RequireDBSizeInGB -MaxMBxPerDB $MaxMBxPerDB
}
Else{
$AllUsersFromDB,$AllUsersArchFromDB=Get-ExDatabaseusage -DBName $DatabaseName | Sort-Object MailboxGB
$TotalDBs=Prepare-MyDBLog -UsersList $AllUsersFromDB -RequireDBSizeInGB $RequireDBSizeInGB -MaxMBxPerDB $MaxMBxPerDB
$TotalArcDBs=Prepare-MyDBLog -UsersList $AllUsersArchFromDB -RequireDBSizeInGB $RequireDBSizeInGB -MaxMBxPerDB $MaxMBxPerDB
}

Write-Host "*************************Report********************" -ForegroundColor Green
Write-Host "Number of DB Required:" -NoNewline -ForegroundColor Green
Write-Host $TotalDBs[-1].DBName -ForegroundColor Red 
if ($EXMBxArchiveLog){Write-Host "Number of Archive DB required is" -ForegroundColor Green -NoNewline
     write-host $TotalArcDBs[-1].DBName -ForegroundColor red}

Write-Host "*************************************" -ForegroundColor Yellow
Write-Host "Number of Mailbox on each Proposed Database"
$TotalDBs | export-csv -Path (Join-Path -Path $OutputFolder -ChildPath "Ex-Planfull.csv") -NoTypeInformation -Force
for ($i=1;$i -le ([int]$TotalDBs[-1].DBName);$i++){
$TotalDBs| where {$_.DBName -match $i} | Measure-Object -Property UserMBXSize -Sum | select count,sum
$TotalDBs| where {$_.DBName -match $i} | select emailaddress |export-csv -Path (join-path -path $OutputFolder -childpath "\EXDB$i.csv") -NoTypeInformation |Out-Null
}

if ($EXMBxArchiveLog){
Write-Host "*************************************" -ForegroundColor Yellow
Write-Host "Number of Archive Mailbox on each Proposed Database"
$TotalArcDBs | export-csv -Path (Join-Path -Path $OutputFolder -ChildPath "ExArch-Planfull.csv") -NoTypeInformation -Force
for ($i=1;$i -le ([int]$TotalArcDBs[-1].DBName);$i++){
$TotalArcDBs| where {$_.DBName -match $i} | Measure-Object -Property UserMBXSize -Sum | select count,sum
$TotalArcDBs| where {$_.DBName -match $i} | select emailaddress |export-csv -Path (join-path -path $OutputFolder -childpath "\Arch-EXDB$i.csv") -NoTypeInformation |Out-Null
}
}
