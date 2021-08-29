<#
PowerShell Module To scan Active Directory ACL 
The Module support three cmdlets

Get-PscDomainRootACL: This cmdlet is meant to only get the ACL for the root domain only.
Get-PscOUACL: This cmdlet is meant to get the ACL for all containers and OU in the domain.
Convert-PscGUIDToName: This cmdlet convert the Active Directory ACL ObjectType GUID to name.
Please Visit https://www.powershellcenter.com/2021/08/29/active-directory-acl-reporter-powershell/ for more information
Contact me at farisnt@gmail.com for any update or issues.

Thanks

#>

#Requires –Modules ActiveDirectory

Function Get-PscDomainRootACL{
    [cmdletbinding()]
    param(
    [parameter(mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$GenerateHTMLPath,
    [parameter(mandatory=$false)][switch]$ExcludeNTAUTHORITY,
    [parameter(mandatory=$false)][switch]$ExcludeBuiltIN,
    [parameter(mandatory=$false)][switch]$ExcludeCreatorOwner,
    [parameter(mandatory=$false)][switch]$ExcludeEveryOne,
    [parameter(mandatory=$false)][switch]$ExcludeGroups
    )
    
    Write-Host "Building Permission list, Please Wait..." -ForegroundColor Yellow -NoNewline
    $DCExtRight = @{}
    $DCExtRight=Convert-PSCGUIDToName -GetFullList
    
    $DCClear=Get-ADObject -Filter * | Where-Object {$_.objectclass -like $null}
    if (!([System.String]::IsNullOrEmpty($DCClear.DistinguishedName))){
        Write-Host "WARNING: It seems there is one or more OU or Container you are not allowed to access"-BackgroundColor red -ForegroundColor White
        Write-Host "Check the following OU and confirm its safe and there is no hidding account."-BackgroundColor red -ForegroundColor White
        $DCClear.DistinguishedName
        $HTMLServerWarning="<H2> Possible Hidden Object</H2>Make sure to check the following DN<br><font color=red> $($DCClear.DistinguishedName)</font>"
        pause
        }
    $TLDResult=@()
    $TLDPer=Get-acl -Path "AD:\$((Get-ADDomain).DistinguishedName)"
    $PermissionName=""
    Foreach($TLDACL in $TLDPer.Access){
    
    if (($PSBoundParameters['ExcludeEveryOne']) -and ($TLDACL.IdentityReference -like "Everyone")){continue}
    if (($PSBoundParameters['ExcludeBuiltIN']) -and ($TLDACL.IdentityReference -like "BUILTIN*")){continue}
    if (($PSBoundParameters['ExcludeCreatorOwner']) -and ($TLDACL.IdentityReference -like "CREATOR OWNER")){continue}
    if (($PSBoundParameters['ExcludeEveryOne']) -and ($TLDACL.IdentityReference -like "Everyone")){continue}
    if (($PSBoundParameters['ExcludeNTAUTHORITY']) -and ($TLDACL.IdentityReference -like "NT AUTHORITY*")){continue}
    if ($PSBoundParameters['ExcludeGroups'] -like $true){
            Try{
                get-adgroup ($TLDACL.IdentityReference.Value.Substring($env:USERDOMAIN.Length+1)) -ErrorAction Stop | Out-Null
                continue        
                }
            Catch{
            
            }}
    
        if ($TLDACL.ActiveDirectoryRights -like "ExtendedRight"){$PermissionName="Extended Permission: $($DCExtRight[[GUID]$TLDACL.ObjectType.Guid])"}
        Else{
        $PermissionName=$TLDACL.ActiveDirectoryRights}
    
        $TLDPermDetails=[pscustomobject]@{
        "Assigned To"=$TLDACL.IdentityReference
        "Rights"=$PermissionName
        "Allow/Deny"=$TLDACL.AccessControlType
        "IsInherited"=$TLDACL.IsInherited
        }
        $TLDResult+=$TLDPermDetails       
        
    
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
        $HTMLContent=$TLDResult | ConvertTo-Html -Fragment -as Table -PreContent "<H2>ACL Control list for the domain</H2>" -PostContent "http://www.powershellcenter.com"
        $FullHTML= ConvertTo-Html -Body "$H1data $HTMLServerWarning $HTMLContent" -Title "AD Security Report" -PostContent "<p>Creation Date: $(Get-Date)<p>" -Head $header
        $FullHTML | Out-File $PSBoundParameters['GenerateHTMLPath']
    
    
    }
    Else{
    Return $TLDResult
    }
    
    }
    Export-ModuleMember Get-PscDomainRootACL
    
    Function Get-PscOUACL{
    [cmdletbinding()]
    param(
    [parameter(mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$GenerateHTMLPath,
    [parameter(mandatory=$false)][switch]$ExcludeNTAUTHORITY,
    [parameter(mandatory=$false)][switch]$ExcludeBuiltIN,
    [parameter(mandatory=$false)][switch]$ExcludeCreatorOwner,
    [parameter(mandatory=$false)][switch]$ExcludeEveryOne,
    [parameter(mandatory=$false)][switch]$ExcludeGroups,
    [parameter(mandatory=$false)][switch]$ExcludeInheritedPermission
    )
    
    Write-Host "Building Permission list, Please Wait..." -ForegroundColor Yellow -NoNewline
    $DCExtRight = @{}
    $DCExtRight=Convert-PSCGUIDToName -GetFullList
    
    $CNOU=Get-ADObject -Properties ObjectClass,objectCategory -Filter '((ObjectClass -like "container") -and (objectCategory -like "container")) -or (objectClass -like "organizationalUnit") -or (Objectclass -like "builtinDomain") -or (objectclass -like "lostAndFound") -or (ObjectClass -like "msDS-QuotaContainer")  -or (ObjectClass -like "msTPM-InformationObjectsContainer")'
    $CheckDC=Get-ADObject -Filter * | Where-Object {$_.objectclass -like $null}
    if (!([System.String]::IsNullOrEmpty($CheckDC.DistinguishedName))){
        Write-Host "WARNING: It seems there is one or more OU or Container you are not allowed to access"-BackgroundColor red -ForegroundColor White
        Write-Host "Check the following OU and confirm its safe and there is no hidding account."-BackgroundColor red -ForegroundColor White
        $CheckDC.DistinguishedName
        $HTMLServerWarning="<H2> Possible Hidden Object</H2>Make sure to check the following DN<br><font color=red> $($CheckDC.DistinguishedName)</font>"
        pause
        }
    $CNOUResult=@()
    Foreach ($Singleobj in $CNOU){
        $CNOUPer=Get-acl -Path "AD:\$($Singleobj.DistinguishedName)"
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
    
     if ($SCNOUACL.ObjectType -notlike "00000000-0000-0000-0000-000000000000"){$PermissionName="$($SCNOUACL.ActiveDirectoryRights) === To Object ==> : $($DCExtRight[[GUID]$SCNOUACL.ObjectType.Guid])"}
        Else{
        $PermissionName=$SCNOUACL.ActiveDirectoryRights}
    
        $CNOUPermDetails=[pscustomobject]@{
        "OU"=$Singleobj.DistinguishedName
        "Assigned To"=$SCNOUACL.IdentityReference
        "Rights"=$PermissionName
        "Allow/Deny"=$SCNOUACL.AccessControlType
        "IsInherited"=$SCNOUACL.IsInherited
        }
       $CNOUResult+=$CNOUPermDetails      
    
    }
      
    
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
    
    
    }
    Else{
    Return $CNOUResult
    }
    
    }
    Export-ModuleMember Get-PscOUACL
    
    Function Convert-PscGUIDToName{
     [Cmdletbinding(DefaultParameterSetName='All')]
    Param(
    [parameter(mandatory=$false,ParameterSetName='All',Position=0)][switch]$GetFullList,
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