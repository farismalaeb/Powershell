
<#PSScriptInfo

.VERSION 1.2

.GUID b1dcac0d-adb4-4895-9580-18bd2a3ce839

.AUTHOR Faris Malaeb

.COMPANYNAME

.COPYRIGHT 2022

.TAGS Active Directory

.LICENSEURI

.PROJECTURI https://www.powershellcenter.com/2021/08/29/active-directory-acl-reporter-powershell/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

#Requires -Module ActiveDirectory
<# 

.DESCRIPTION 
 Report Active Directory ACL and detect hidden accounts 
.Example
To Scan your all AD tree and generate an HTML report
 Get-PscActiveDirectoryACL -GenerateHTMLPath 'C:\MyADReport.html' -ACLToInclude All

To Scan only the top level domain
  Get-PscActiveDirectoryACL -GenerateHTMLPath 'C:\MyADReport.html' -ACLToInclude TopLevelDomainOnly

To Scan only the OU without the Top Level Domain TLD
  Get-PscActiveDirectoryACL -GenerateHTMLPath 'C:\MyADReport.html' -ACLToInclude OUScanOnly

To Scan a single OU
  Get-PscActiveDirectoryACL -GenerateHTMLPath 'C:\MyADReport.html' -ScanDNName "OU=MyOU,DC=Domain,DC=Local"
#>

Function Get-PscActiveDirectoryACL{
[cmdletbinding(DefaultParameterSetName='All')]
param(
[parameter(mandatory=$false,ParameterSetName='All')]
[parameter(ParameterSetName='OneDN')]
[ValidateNotNullOrEmpty()]
[string]$GenerateHTMLPath,
[parameter(mandatory=$false,ParameterSetName='All')]
[parameter(ParameterSetName='OneDN')]
[ValidateNotNullOrEmpty()]
[string]$GenerateCSVPath,
[parameter(mandatory=$false)][switch]$ExcludeNTAUTHORITY,
[parameter(mandatory=$false)][switch]$ExcludeBuiltIN,
[parameter(mandatory=$false)][switch]$ExcludeCreatorOwner,
[parameter(mandatory=$false)][switch]$ExcludeEveryOne,
[parameter(mandatory=$false)][switch]$ExcludeGroups,
[parameter(mandatory=$false)][switch]$ExcludeInheritedPermission,
[parameter(mandatory=$false)][switch]$DontRunBasicSecurityCheck,
[parameter(mandatory=$true,ParameterSetName='All',
           HelpMessage="Type one of the following: TopLevelDomainOnly or OUScanOnly or All")]
[validateset("TopLevelDomainOnly","OUScanOnly","All")]$ACLToInclude,
[parameter(mandatory=$true,ParameterSetName='OneDN')]$ScanDNName
)

write-host "Scanning started, This process can take minuts to finish, so please wait." -ForegroundColor Yellow 
Write-Host "Building Permission list, Please Wait..." -ForegroundColor Yellow -NoNewline
$DCExtRight = @{}
$DCExtRight=Convert-PSCGUIDToName -GetFullList
Write-Host "Completed." -ForegroundColor Green


    if ($PSBoundParameters.ContainsKey('ACLToInclude')){
       switch ($ACLToInclude){
        TopLevelDomainOnly {$CNOU=(Get-ADObject "$((Get-ADDomain).DistinguishedName)").DistinguishedName}
        OUScanOnly {$CNOU=(Get-ADObject -Properties ObjectClass,objectCategory -Filter '((ObjectClass -like "container") -and (objectCategory -like "container")) -or (objectClass -like "organizationalUnit") -or (Objectclass -like "builtinDomain") -or (objectclass -like "lostAndFound") -or (ObjectClass -like "msDS-QuotaContainer")  -or (ObjectClass -like "msTPM-InformationObjectsContainer")').DistinguishedName}
        All {$CNOU=(Get-ADObject -Properties ObjectClass,objectCategory -Filter '((ObjectClass -like "container") -and (objectCategory -like "container")) -or (objectClass -like "organizationalUnit") -or (Objectclass -like "builtinDomain") -or (objectclass -like "lostAndFound") -or (ObjectClass -like "msDS-QuotaContainer")  -or (ObjectClass -like "msTPM-InformationObjectsContainer")').DistinguishedName
                 $CNOU+=(Get-ADObject "$((Get-ADDomain).DistinguishedName)").DistinguishedName}
         }
     }
      if ($PSBoundParameters.ContainsKey('ScanDNName')){
          try{
            if (Test-Path "AD:$ScanDNName"){$CNOU=(Get-ADObject -SearchBase $ScanDNName -Filter '((ObjectClass -like "container") -and (objectCategory -like "container")) -or (objectClass -like "organizationalUnit") -or (Objectclass -like "builtinDomain") -or (objectclass -like "lostAndFound") -or (ObjectClass -like "msDS-QuotaContainer")  -or (ObjectClass -like "msTPM-InformationObjectsContainer")').DistinguishedName}
            else{Throw "Path not found, make sure its a DN format"}
          }
              catch{
              Throw $Error[0]
          }
 }


  if (!($PSBoundParameters['DontRunBasicSecurityCheck'])){

    $CheckDC=Get-ADObject -Filter * | Where-Object {$_.objectclass -like $null}
        if (!([System.String]::IsNullOrEmpty($CheckDC.DistinguishedName))){
            Write-Host "WARNING: It seems there is one or more OU or Container you are not allowed to access"-BackgroundColor red -ForegroundColor White
            Write-Host "Check the following $($CheckDC.DistinguishedName) and confirm its safe and there is no hidding account."-BackgroundColor red -ForegroundColor White
            $HTMLServerWarning="<H2> Possible Hidden Object</H2>Make sure to check the following DN<br><font color=red> $($CheckDC.DistinguishedName)</font>"
            pause
        }
    }

$CNOUResult=@()
Foreach ($Singleobj in $CNOU){
    $CNOUPer=Get-acl -Path "AD:\$($Singleobj)"
        Foreach($SCNOUACL in $CNOUPer.Access){
            if (($PSBoundParameters['ExcludeEveryOne']) -and ($SCNOUACL.IdentityReference -like "Everyone")){continue}
            if (($PSBoundParameters['ExcludeBuiltIN']) -and ($SCNOUACL.IdentityReference -like "BUILTIN*")){continue}
            if (($PSBoundParameters['ExcludeCreatorOwner']) -and ($SCNOUACL.IdentityReference -like "CREATOR OWNER")){continue}
            if (($PSBoundParameters['ExcludeEveryOne']) -and ($SCNOUACL.IdentityReference -like "Everyone")){continue}
            if (($PSBoundParameters['ExcludeNTAUTHORITY']) -and ($SCNOUACL.IdentityReference -like "NT AUTHORITY*")){continue}
            if (($PSBoundParameters['ExcludeInheritedPermission']) -and ($SCNOUACL.IsInherited -like $true)){continue}
            if ($PSBoundParameters['ExcludeGroups'] -like $true){
                    Try{
                        get-adgroup ($SCNOUACL.IdentityReference.Value.Substring($env:USERDOMAIN.Length+1)) -ErrorAction Stop | Out-Null
                        continue        
                        }
                    Catch{
        
                    }}

 if (!($SCNOUACL.ObjectType -like "00000000-0000-0000-0000-000000000000")){$PermissionName="$(TranslatePermission -PermList ($SCNOUACL.ActiveDirectoryRights)) ==> $($DCExtRight[[GUID]$SCNOUACL.ObjectType.Guid])"}
    Else{
    $PermissionName="$(TranslatePermission -PermList $SCNOUACL.ActiveDirectoryRights) ==> All Properties"}
 if ($SCNOUACL.InheritedObjectType -like "00000000-0000-0000-0000-000000000000"){$InheritedObjectType="All AD Objects"}
     Else{$InheritedObjectType=$DCExtRight[[GUID]$SCNOUACL.InheritedObjectType.Guid]
            }


    $CNOUPermDetails=[pscustomobject]@{
    "Assigned To"=$SCNOUACL.IdentityReference
    "Rights"=$PermissionName
    "TargettedObject"= $InheritedObjectType
    "Allowed-Denied"=$SCNOUACL.AccessControlType
    "IsInherited"=$SCNOUACL.IsInherited
    "Path"=$Singleobj
    }
   $CNOUResult+=$CNOUPermDetails      

}
  

}

if ($PSBoundParameters['GenerateCSVPath']){
    $CNOUResult | Export-Csv -Path $PSBoundParameters['GenerateCSVPath'] -NoTypeInformation 
}

if ($PSBoundParameters['GenerateHTMLPath']){

Write-host "Generating HTML Report, Please wait..." -ForegroundColor Green

$header = @"
<style>

    h1 {

        font-family: Arial, Helvetica, sans-serif;
        color: #e68a00;
        font-size: 28px;

    } 

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

      #CreationDate {

        font-family: Arial, Helvetica, sans-serif;
        color: #ff3300;
        font-size: 12px;

    }
</style>

"@
    $H1data="<h1>Security Report for $((Get-ADDomain).DNSRoot)</h1>"
    $HTMLContent=$CNOUResult | ConvertTo-Html -Fragment -as Table -PreContent "<H2>OU ACL Control list</H2>" -PostContent "http://www.powershellcenter.com"
    $FullHTML= ConvertTo-Html -Body "$H1data $HTMLServerWarning $HTMLContent" -Title "AD Security Report" -PostContent "<p>Creation Date: $(Get-Date)<p>" -Head $header
    $FullHTML | Out-File $PSBoundParameters['GenerateHTMLPath']
    Write-Host "Report Ready.. "-ForegroundColor Green

}
if ((!($PSBoundParameters['GenerateCSVPath']))-and (!($PSBoundParameters['GenerateHTMLPath']))){Return $CNOUResult}
}
Export-ModuleMember Get-PscActiveDirectoryACL

Function TranslatePermission{
    param(
    [string]$PermList
    )
    $UpdatedPrelist=@()
                Foreach ($PermItem in ($PermList.Split(", ") | Where-Object {$_ -notlike $null})){
                    switch ($PermItem){
                        'WriteProperty' {$UpdatedPrelist+='Can Write'}
                        'AccessSystemSecurity' {$UpdatedPrelist+='Set SCAL "Audit"'}
                        'GenericAll' {$UpdatedPrelist+='Full Control'}
                        'GenericExecute' {$UpdatedPrelist+='Read Permissions, List Content'}
                        'GenericRead' {$UpdatedPrelist+='Read all properties'}
                        'GenericWrite' {$UpdatedPrelist+='Write all properties'}
                        'WriteDacl' {$UpdatedPrelist+='Change Permissions'}
                        'WriteOwner' {$UpdatedPrelist+='Change Owner'}
                        'ExtendedRight' {$UpdatedPrelist+='Advanced Permission'}
                         Default {$UpdatedPrelist+= $PermItem}
                         }
                    
                }               
                return ($UpdatedPrelist -join ', ')
    
    }



Function Convert-PscGUIDToName{
 [Cmdletbinding(DefaultParameterSetName='All')]
Param(
[parameter(mandatory=$false,ParameterSetName='All',Position=0)][switch]$GetFullList=$true,
[parameter(mandatory=$true,ParameterSetName='SingleGUIDtoName',ValueFromPipeline,Position=0)]
[ValidatePattern('^[{]?[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}[}]?$')]$GUID2Name
)

Begin{
    $DCExtRight = @{}
    $OldErrorAction=$ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
}
Process{
    if (!($DCExtRight.Count -gt 0)){
        (Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID).foreach({$DCExtRight.add([GUID]$_.schemaIDGUID,$_.name)})
        (Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID).ForEach({$DCExtRight.add([GUID]$_.rightsGUID,$_.name)})
    }
    if ($PSCmdlet.ParameterSetName -like 'All'){

        return $DCExtRight
    }
    Else{
        return $DCExtRight[[GUID]$PSBoundParameters['GUID2Name']]

    }
}

End{
    $ErrorActionPreference = $OldErrorAction

}


}

Export-ModuleMember Convert-PscGUIDToName


write-host "PowerShell Version: "$($PSVersionTable.PSVersion.Major)
write-host "AD Module Version: "$((get-module activedirectory).Version.Build)
write-host "You are using version 1.3"

if (($PSVersionTable.PSVersion.Major -eq 7) -and (get-module activedirectory).Version.Build -ne 1 ){
Write-Host "********* Cannot start **********" -ForegroundColor Red
Write-Host "Sorry, But This script dont support PowerShell 7 with ActiveDirectory Module Version 1.0.0.0 `nPlease use PowerShell 5..." -ForegroundColor Red
Write-Host "If you want to use PowerShell 7, then try it on Windows 2019, as ActiveDirectory Module there is 1.0.1.0, not 1.0.0.0" -ForegroundColor Red
write-host "The Issue is the PSDrive is not created in PS7 and AD Module build 0" -ForegroundColor Red
Throw "Cannot continue.. I am dead X-("
}