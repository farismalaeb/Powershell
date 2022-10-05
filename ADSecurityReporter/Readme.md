## Scan Active Directory Access Control List (ACL).

### Update for version 1.3

Added -GenerateCSVPath to generate CSV file also, you can use the GenerateCSVPath with the GenerateHTMLPath if you want.

If neither GenerateHTMLPath nor GenerateCSVPath are used then the script return the results as objects through the pipeline.

Also basic fix and minor updates are applied.

### Update for version 1.2

Script Compatibility check, As the script wont work with PS7 and Active Directory module built version 0.

You can check the version by running `(get-module activedirectory).Version.Build
Fix issues related to empty parameters.
Fix small bugs.

### Update for version 1.1.1

- No more seperate cmdlet to scan the domain, instead use the main cmdlet **Get-PscActiveDirectoryACL** and set the parameter **ACLToInclude** to **All**, **DCOnly** or **OUScanOnly**
- Added **ScanDNName** parameter to scan an OU or container tree instead of scanning the entire ActiveDirectory
- Better reporting. The report can tell exactly each ADObject to which property is allowed or denied access.
- Show to which object type (Users, Groups, Computers, Contact...etc.) the permission are applied to
- Added **DontRunBasicSecurityCheck** parameter to bypass the basic security check.
- Include basic spelling correction.

### Available Cmdlets

**Get-PscActiveDirectoryACL**: This cmdlet is meant to get the ACL for the Active Directory.
**Convert-PscGUIDToName**: This cmdlet convert the Active Directory ACL ObjectType GUID to.

### Supported Cmdlet for Get-PscActiveDirecotryACL

- **DontRunBasicSecurityCheck**: Bypass a basic security check which try to detect if there is any hidden AD Object. [Switch]
- **GenerateHTMLPath**: Generate HTML report.[string]
- _[Mandatory]_**ACLToInclude**: Define the scanning scope which include [ValidateSet].

    _All_: Scan the enteir Active Directory tree.
    
    _TopLevelDomainOnly_: Scan the root domain controller only.
    
    _OUScanOnly_: Scan all OU and Containers without scanning the Top Level Domain.
    
- **ScanDNName**: Scan a part of Active Directory, for example an OU Tree. The path should be distinguished name format.
- **ExcludeNTAUTHORITY**: Exclude NTAuthority from the results.[switch]
- **ExcludeInheritedPermission**: Exclude Inherited permission and show only explicit assigned permissions.
- **ExcludeBuiltIN**: Exclude Builtin account such as Administrators from the results.[switch]
- **ExcludeCreatorOwner**: Exclude CreatorOwner from the results.[switch]
- **ExcludeEveryOne**: Exclude Everyone group from the results.[switch]
- **ExcludeGroups**: Exclude Active Directory groups from the results.[switch]

https://www.powershellcenter.com/2021/08/29/active-directory-acl-reporter-powershell/
