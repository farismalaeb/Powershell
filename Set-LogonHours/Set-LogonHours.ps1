Function Set-LogonHours{
 [CmdletBinding()]
 Param(
 [Parameter(Mandatory=$True)]
 [ValidateRange(0,23)]
 $TimeIn24Format,
 [Parameter(Mandatory=$True,
 ValueFromPipeline=$True,
 ValueFromPipelineByPropertyName=$True, 
 Position=0)]$Identity,
 [parameter(mandatory=$False)]
 [ValidateSet("WorkingDays", "NonWorkingDays")]$NonSelectedDaysare="NonWorkingDays",
 [parameter(mandatory=$false)][switch]$Sunday,
 [parameter(mandatory=$false)][switch]$Monday,
 [parameter(mandatory=$false)][switch]$Tuesday,
 [parameter(mandatory=$false)][switch]$Wednesday,
 [parameter(mandatory=$false)][switch]$Thursday,
 [parameter(mandatory=$false)][switch]$Friday,
 [parameter(mandatory=$false)][switch]$Saturday
 )
 Process{
 $FullByte=New-Object "byte[]" 21
 $FullDay=[ordered]@{}
 0..23 | foreach{$FullDay.Add($_,"0")}
 $TimeIn24Format.ForEach({$FullDay[$_]=1})
 $Working= -join ($FullDay.values)
 Switch ($PSBoundParameters["NonSelectedDaysare"])
 {
 'NonWorkingDays' {$SundayValue=$MondayValue=$TuesdayValue=$WednesdayValue=$ThursdayValue=$FridayValue=$SaturdayValue="000000000000000000000000"}
 'WorkingDays' {$SundayValue=$MondayValue=$TuesdayValue=$WednesdayValue=$ThursdayValue=$FridayValue=$SaturdayValue="111111111111111111111111"}
 }
 Switch ($PSBoundParameters.Keys)
 {
 'Sunday' {$SundayValue=$Working}
 'Monday' {$MondayValue=$Working}
 'Tuesday' {$TuesdayValue=$Working}
 'Wednesday' {$WednesdayValue=$Working}
 'Thursday' {$ThursdayValue=$Working}
 'Friday' {$FridayValue=$Working}
 'Saturday' {$SaturdayValue=$Working}
 }
 $AllTheWeek="{0}{1}{2}{3}{4}{5}{6}" -f $SundayValue,$MondayValue,$TuesdayValue,$WednesdayValue,$ThursdayValue,$FridayValue,$SaturdayValue
# Timezone Check
 if ((Get-TimeZone).baseutcoffset.hours -lt 0){
 $TimeZoneOffset = $AllTheWeek.Substring(0,168+ ((Get-TimeZone).baseutcoffset.hours))
 $TimeZoneOffset1 = $AllTheWeek.SubString(168 + ((Get-TimeZone).baseutcoffset.hours))
 $FixedTimeZoneOffSet="$TimeZoneOffset1$TimeZoneOffset"
 }
 if ((Get-TimeZone).baseutcoffset.hours -gt 0){
 $TimeZoneOffset = $AllTheWeek.Substring(0,((Get-TimeZone).baseutcoffset.hours))
 $TimeZoneOffset1 = $AllTheWeek.SubString(((Get-TimeZone).baseutcoffset.hours))
 $FixedTimeZoneOffSet="$TimeZoneOffset1$TimeZoneOffset"
 }
 if ((Get-TimeZone).baseutcoffset.hours -eq 0){
 $FixedTimeZoneOffSet=$AllTheWeek
 }
 $i=0
 $BinaryResult=$FixedTimeZoneOffSet -split '(\d{8})' | Where {$_ -match '(\d{8})'}
 Foreach($singleByte in $BinaryResult){
 $Tempvar=$singleByte.tochararray()
 [array]::Reverse($Tempvar)
 $Tempvar= -join $Tempvar
 $Byte = [Convert]::ToByte($Tempvar, 2)
 $FullByte[$i]=$Byte
 $i++
 }
 Set-ADUser  -Identity $Identity -Replace @{logonhours = $FullByte}                                   
 }
 end{
 Write-Output "All Done :)"
 }
 }

# Change the LogonHours for all the users in the Test OI
 Get-ADUser -SearchBase "OU=Test,DC=test,DC=local" -Filter *| Set-LogonHours -TimeIn24Format @(8,9,10,11,12,13,14,15,16)  -Monday -Tuesday -Wednesday -Thursday -NonSelectedDaysare WorkingDays 
# Change the LogonHours for a single user
 Set-LogonHours -Identity Jack.Ripper -TimeIn24Format @(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,0) -Monday -Tuesday -Wednesday -Thursday -Friday -NonSelectedDaysare NonWorkingDays # Allow Access during weekday
