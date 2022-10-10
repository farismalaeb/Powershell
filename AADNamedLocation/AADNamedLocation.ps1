#Import-Module Microsoft.Graph.Identity.SignIns
Connect-MgGraph -Scopes ('Policy.Read.All', 'Policy.ReadWrite.ConditionalAccess') -ForceRefresh
$CSV=Import-Csv D:\TrustedLocation.csv


foreach ($singleLocation in $csv){
$params = @{
	"@odata.type" = "#microsoft.graph.ipNamedLocation"
	DisplayName = $singleLocation.DisplayName
}
	switch ($singleLocation.MarkAsTrusted) {
		0 { $params.Add("IsTrusted",$false) }
		1 { $params.Add("IsTrusted",$true) }
	}
$params.Add("IpRanges",@())


Foreach ($S in ($singleLocation.IPRange).Split("-")){
$IpRanges=@{}
$IpRanges.add("@odata.type" , "#microsoft.graph.iPv4CidrRange")
$IpRanges.add("CidrAddress" , $S)
$params.IpRanges+=$IpRanges

}
New-MgIdentityConditionalAccessNamedLocation -BodyParameter $params
}

#Get-MgIdentityConditionalAccessNamedLocation -Debug  
#get-MgIdentityConditionalAccessNamedLocation
#New-MgIdentityConditionalAccessNamedLocation -BodyParameter $params