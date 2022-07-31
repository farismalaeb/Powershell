<#
.SYNOPSIS
   Report On-Preim AD Users and which Groups they are joined to
.DESCRIPTION
   This script show a report of each AD User and the groups this user is member of
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    .\GRoupReporter.ps1 -FileToSave C:\MyADUserReport.csv
#>

Param(
[Parameter(Mandatory=$True)]
[ValidateNotNull()]
[string]$FileToSave
)

[System.Collections.ArrayList]$fullReport=@()
$AllUsers=Get-ADUser -Filter 'Enabled -eq  $true' -Properties Name,givenName,userPrincipalName
$CSVheaderNumber=0
$CSVIndex=0
foreach ($singleuser in $AllUsers)

{
    $Report=[PSCustomObject]@{
        Name = $singleuser.Name
        givenName=$singleuser.GivenName
        userPrincipalName=$singleuser.userPrincipalName
    }
    write-host "Processing User: $($singleuser.SamAccountName)"  -ForegroundColor Green
    $AllGroups=Get-ADPrincipalGroupMembership $singleuser.SamAccountName 

    if ($AllGroups.name.Count -gt $CSVheaderNumber){ $CsvHeaderNumber=$AllGroups.Count;$CSVIndex=$fullReport.Count}
    if ($AllGroups.name.count -eq 1){
        $Report | Add-Member -NotePropertyName "Group0" -NotePropertyValue $AllGroups.name
    }
        Else{
        for ($i = 0; $i -lt $AllGroups.name.count; $i++) 
        {
        $GroupName=Get-ADGroup -Identity $AllGroups[$i].SamAccountName

            $Report | Add-Member -NotePropertyName "Group$i" -NotePropertyValue $GroupName.name
        }
        }

    $fullReport.Add($Report) | Out-Null
}
$fullReport[$CSVIndex] | Export-Csv -Path $PSBoundParameters['FileToSave'] -NoTypeInformation
$fullReport[0..($CSVIndex -1)+($CSVIndex +1)..$fullReport.count] | Export-Csv -Path $PSBoundParameters['FileToSave'] -NoTypeInformation -Append -Force