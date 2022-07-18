param(
[cmdletbinding()]
[Parameter()][switch]$IncludeonPremise
)
Connect-MgGraph -Scopes @('Group.Read.all')
Select-MgProfile -Name beta
$FullResults=@()
switch ($PSBoundParameters.ContainsKey('IncludeonPremise')){
    $true {$AllGroups=Get-MgGroup -All}
    $false {$AllGroups=Get-MgGroup -All |Where-Object {$_.OnPremisesSyncEnabled -notlike $true}}
}

foreach ($SingleGroup in $AllGroups){
    $Result=[PSCustomObject]@{
        GroupName = $SingleGroup.DisplayName
        Description=$SingleGroup.Description
        CloudID=$SingleGroup.Id
        GroupTypes=''
        WriteBackEnabled=$SingleGroup.AdditionalProperties.writebackConfiguration.isEnabled
        WriteBackAs=$SingleGroup.AdditionalProperties.writebackConfiguration.onPremisesGroupType
        Source=''
        OnPremisesSamAccountName=$SingleGroup.OnPremisesSamAccountName
        OnPremisesSecurityIdentifier=$SingleGroup.OnPremisesSecurityIdentifier
    }

switch ($SingleGroup) {
    {$_.GroupTypes -contains "Unified"}{$Result.GroupTypes='Unified'}
    {($_.GroupTypes -notcontains "Unified") -and ($_.mailEnabled -like $false) -and ($_.securityEnabled -like $true)}{$Result.GroupTypes='Security'}
    {($_.GroupTypes -notcontains "Unified") -and ($_.mailEnabled -like $true) -and ($_.securityEnabled -like $true)}{$Result.GroupTypes= "Mail-enabled security groups"}
    {($_.GroupTypes -notcontains "Unified") -and ($_.mailEnabled -like $true) -and ($_.securityEnabled -like $False)}{$Result.GroupTypes= "Distribution groups"}
    {($_.OnPremisesSyncEnabled -like $true)}{$Result.Source="OnPremis"}
    {($_.OnPremisesSyncEnabled -like $null)}{$Result.Source="Cloud"}
}

$FullResults+=$Result

}

    
    return $FullResults



