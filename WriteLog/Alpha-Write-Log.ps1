Function Write-PSCLog{
    Param(
        $Message,
        [parameter(mandatory)]
        [ValidateSet("Critical","High","Normal","Low","Information")]
        $ErrorLevel
    )

    $logpath=(Join-Path $MyInvocation.PSScriptRoot -ChildPath "PasswordLog.txt")
    $ValuetoWrite=$PSBoundParameters['ErrorLevel'] +"  " + (Get-date).ToLongTimeString() +": " + $PSBoundParameters['Message']
    write-host $Logpath
    if (Test-Path $logpath){
        add-Content $logpath -Value $ValuetoWrite 
    }
    else{
        New-Item -Path $MyInvocation.PSScriptRoot -Name "PasswordLog.txt" -ItemType File -Value "$($ValuetoWrite)`n"
    }

}

Write-PSCLog -Message "Error Message, Level Cretical" -ErrorLevel Critical