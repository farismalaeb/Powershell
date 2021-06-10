<#
Testing SQL connection and server availability
#>

param(
[parameter(mandatory)]$Servername,
[parameter(mandatory)]$To,
[parameter(Mandatory=$false)]$PauseForInSecond=120,
[parameter(mandatory)]$SMTPServer

)

Function AddLog{
param(
$LogMessage
)
Write-Host $LogMessage
Add-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath "SQLConnectivityTest.txt") -Value "$(Get-date) ----> $($LogMessage)"

}
while ($true){

Try{
        AddLog -LogMessage "New Check started..."
        AddLog -LogMessage "Checking The $($Servername)"
        $TestNetConnection=Test-NetConnection -ComputerName $Servername -Port 1433
        if (!($TestNetConnection.TcpTestSucceeded )){ Send-MailMessage Send-MailMessage -From "SQLMon@Domain.com" -To $To -SmtpServer $SMTPServer -Body $TestNetConnection}
        else{
        AddLog -LogMessage  "Testing Database connection"
        $connectionString = 'Data Source={0};initial catalog=master;Integrated Security=true;' -f $Servername
        $SQLCommands = @'
select sysdatetime()
'@
        AddLog -LogMessage "Connecting to $($connectionString)"
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
        $SqlCmd = New-Object System.Data.SqlClient.SqlCommand
        $SqlCmd.CommandText = $SQLCommands
        $SqlCmd.Connection = $connectionString 

        $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
        $SqlAdapter.SelectCommand = $SqlCmd
        $DataSet = New-Object System.Data.DataSet
        addlog -LogMessage "Sending Data"
        $SqlAdapter.Fill($DataSet)
        $SQLData=$DataSet.Tables[0]
        AddLog -LogMessage  $SQLData.Column1
        AddLog -LogMessage "Closing Connection"
        $sqlConnection.Close()
        }

Start-Sleep  $PauseForInSecond

}

catch{
Write-Host $Error[0]
Send-MailMessage -From "SQLMon@Domain.com" -To $To -SmtpServer $SMTPServer -Body $Error[0]
}

}