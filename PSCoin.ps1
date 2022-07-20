function Register-PSCCoinAuthKey {
    param (
    [Parameter(mandatory=$true)]$APIKey
    )
    Write-Host "You are registering the following API Key" 
    Write-Host $($PSBoundParameters['APIKey']).ToString().ToUpper() -ForegroundColor Green
    Write-Host "This key is used for all the API calls, you can change it by running Register-PSCCoinAuthKey again"
    try{
    if (!(Test-Path 'HKCU:\SOFTWARE\PSCCoin' -ErrorAction Ignore)){New-Item -Path HKCU:\SOFTWARE -ItemType key -Name "PSCCoin" -ErrorAction Stop}
    if (!(Get-ItemProperty 'HKCU:\SOFTWARE\PSCCoin' -Name "ApiKey" -ErrorAction Ignore)){New-ItemProperty -Path HKCU:\SOFTWARE\PSCCoin -Name "APIKey" -PropertyType MultiString -Value $PSBoundParameters['APIKey']  -ErrorAction Stop}
         Else{
            Set-ItemProperty -Path "HKCU:\SOFTWARE\PSCCoin" -Name 'ApiKey' -Value $APIKey -ErrorAction stop
        }
   

    }
    catch {
        $Error[0]
    }
    
}

Function LoadAPIKey{

    try{
    $APIAuthKey=Get-ItemProperty 'HKCU:\SOFTWARE\PSCCoin' -Name "ApiKey"
    return $APIAuthKey.APIKey
    }
    catch{
        $Error[0]
    }

}

Function Get-PSCAllCoinsymbols{
[CmdletBinding()]
param (
    [parameter(mandatory=$false)][switch]$IncludeReleaseDate
)

    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }
   $AllCoinInfo=Invoke-RestMethod -Uri 'https://min-api.cryptocompare.com/data/blockchain/list' -Method Get -Headers $Header
    

$AllCoinInfoResults=@()
foreach ($singlecoininfo in ($AllCoinInfo.data | Get-Member -MemberType NoteProperty ).Name){
    switch ($PSBoundParameters['IncludeReleaseDate']) {
        $true {  
            $AllCoinInfoObj=[PSCustomObject]@{
                'NameCode' = $singlecoininfo
                'ReleaseDate'=(([System.DateTimeOffset]::FromUnixTimeSeconds($allcoininfo.Data.$singlecoininfo.data_available_from)).DateTime).ToString() 
            }
        }
        default {
            $AllCoinInfoObj=[PSCustomObject]@{
                'NameCode' = $singlecoininfo
            }
        }
    }

$AllCoinInfoResults+=$AllCoinInfoObj 
}
return $AllCoinInfoResults
}


<#function Get-PSCCoinDetails {
    [CmdletBinding()]
param (
    
)

    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }
   $AllCoinMapping=Invoke-RestMethod -Uri 'https://min-api.cryptocompare.com/data/all/coinlist' -Method Get -Headers $Header
    

$CoinmapResults=@()
foreach ($singlecoinmap in ($AllCoinMapping.data | Get-Member).Name){
$AllCoinmapObj=[PSCustomObject]@{
    'CoinID' = $singlecoinmap.id
#    'ReleaseDate'=(([System.DateTimeOffset]::FromUnixTimeSeconds($allcoininfo.Data.$singlecoininfo.data_available_from)).DateTime).ToString() 
#}
#$AllCoinInfoResults+=$AllCoinInfoObj 
}
return $AllCoinInfoResults
    
}
#>

function Get-PSCCoinLatest {
    [CmdletBinding()]
param (
    $CoinShortCode
)

    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }
   $AllCoinLatest=Invoke-RestMethod -Uri "https://min-api.cryptocompare.com/data/blockchain/latest?fsym=$($CoinShortCode)" -Method Get -Headers $Header | select id,Symbol
   
return $AllCoinLatest.Data
    
}


function Get-PSCCoinPrice {
    [CmdletBinding(DefaultParameterSetName='Single')]
param (
    
    [Parameter(Mandatory=$true,ValueFromPipeline,ParameterSetName="Single",Position=0)]
    [string]$CoinShortCode,
    [Parameter(Mandatory=$false,ParameterSetName="All")][Switch]$All

)
BEGIN {
    <#
    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }#>
}

PROCESS {
    switch ($PSBoundParameters['All']) {
        $true { 
            $CoinSym=(Get-PSCAllCoinsymbols).NameCode
            Write-Host "There is $(($CoinSym).count) to load, This might take several minuts" -ForegroundColor Green
            Write-Host "Use Pipeline for a faster results, for example:" -ForegroundColor Green
            Write-Host " `"BTC`",`"ETH`" | Get-PSCCoinPrice" -ForegroundColor Yellow
            $CoinSym | Get-PSCCoinPrice 
          }
        Default {
            $AllCoinLatest=Invoke-RestMethod -Uri "https://min-api.cryptocompare.com/data/price?fsym=$($PSBoundParameters['CoinShortCode'])&tsyms=USD" -Method Get #-Headers $Header
            if ($AllCoinLatest.Response -like "Error"){
            return @{($PSBoundParameters['CoinShortCode'])= $AllCoinLatest.Message}}
            Else{
                return @{($PSBoundParameters['CoinShortCode'])= $AllCoinLatest.USD}}
            }
        }
    }
   
}


Function New-PSCCoinWalet {
# Specifies a path to one or more locations.
param(
[Parameter(Mandatory=$true)][string[]]$Path
)

}
Function New-PSCCoinAlert {
param(
    [parameter(Mandatory)]$CoinSymbol,
    [parameter(Mandatory)]$AlertOnPrice,
    [parameter(mandatory)]
    [ValidateSet("SMTP","WriteToFile")]
    $AltertViaChannel
)

}
function Register-PSCCoinAuthKey {
    param (
    [Parameter(mandatory=$true)]$APIKey
    )
    Write-Host "You are registering the following API Key" 
    Write-Host $($PSBoundParameters['APIKey']).ToString().ToUpper() -ForegroundColor Green
    Write-Host "This key is used for all the API calls, you can change it by running Register-PSCCoinAuthKey again"
    try{
    if (!(Test-Path 'HKCU:\SOFTWARE\PSCCoin' -ErrorAction Ignore)){New-Item -Path HKCU:\SOFTWARE -ItemType key -Name "PSCCoin" -ErrorAction Stop}
    if (!(Get-ItemProperty 'HKCU:\SOFTWARE\PSCCoin' -Name "ApiKey" -ErrorAction Ignore)){New-ItemProperty -Path HKCU:\SOFTWARE\PSCCoin -Name "APIKey" -PropertyType MultiString -Value $PSBoundParameters['APIKey']  -ErrorAction Stop}
         Else{
            Set-ItemProperty -Path "HKCU:\SOFTWARE\PSCCoin" -Name 'ApiKey' -Value $APIKey -ErrorAction stop
        }
   

    }
    catch {
        $Error[0]
    }
    
}

Function LoadAPIKey{

    try{
    $APIAuthKey=Get-ItemProperty 'HKCU:\SOFTWARE\PSCCoin' -Name "ApiKey"
    return $APIAuthKey.APIKey
    }
    catch{
        $Error[0]
    }

}

Function Get-PSCAllCoinsymbols{
[CmdletBinding()]
param (
    [parameter(mandatory=$false)][switch]$IncludeReleaseDate
)

    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }
   $AllCoinInfo=Invoke-RestMethod -Uri 'https://min-api.cryptocompare.com/data/blockchain/list' -Method Get -Headers $Header
    

$AllCoinInfoResults=@()
foreach ($singlecoininfo in ($AllCoinInfo.data | Get-Member -MemberType NoteProperty ).Name){
    switch ($PSBoundParameters['IncludeReleaseDate']) {
        $true {  
            $AllCoinInfoObj=[PSCustomObject]@{
                'NameCode' = $singlecoininfo
                'ReleaseDate'=(([System.DateTimeOffset]::FromUnixTimeSeconds($allcoininfo.Data.$singlecoininfo.data_available_from)).DateTime).ToString() 
            }
        }
        default {
            $AllCoinInfoObj=[PSCustomObject]@{
                'NameCode' = $singlecoininfo
            }
        }
    }

$AllCoinInfoResults+=$AllCoinInfoObj 
}
return $AllCoinInfoResults
}


<#function Get-PSCCoinDetails {
    [CmdletBinding()]
param (
    
)

    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }
   $AllCoinMapping=Invoke-RestMethod -Uri 'https://min-api.cryptocompare.com/data/all/coinlist' -Method Get -Headers $Header
    

$CoinmapResults=@()
foreach ($singlecoinmap in ($AllCoinMapping.data | Get-Member).Name){
$AllCoinmapObj=[PSCustomObject]@{
    'CoinID' = $singlecoinmap.id
#    'ReleaseDate'=(([System.DateTimeOffset]::FromUnixTimeSeconds($allcoininfo.Data.$singlecoininfo.data_available_from)).DateTime).ToString() 
#}
#$AllCoinInfoResults+=$AllCoinInfoObj 
}
return $AllCoinInfoResults
    
}
#>

function Get-PSCCoinLatest {
    [CmdletBinding()]
param (
    $CoinShortCode
)

    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }
   $AllCoinLatest=Invoke-RestMethod -Uri "https://min-api.cryptocompare.com/data/blockchain/latest?fsym=$($CoinShortCode)" -Method Get -Headers $Header | select id,Symbol
   
return $AllCoinLatest.Data
    
}


function Get-PSCCoinPrice {
    [CmdletBinding(DefaultParameterSetName='Single')]
param (
    
    [Parameter(Mandatory=$true,ValueFromPipeline,ParameterSetName="Single",Position=0)]
    [string]$CoinShortCode,
    [Parameter(Mandatory=$false,ParameterSetName="All")][Switch]$All

)
BEGIN {
    <#
    $Header=@{
        'authorization'= "Apikey $(LoadAPIKey)"
    }#>
}

PROCESS {
    switch ($PSBoundParameters['All']) {
        $true { 
            $CoinSym=(Get-PSCAllCoinsymbols).NameCode
            Write-Host "There is $(($CoinSym).count) to load, This might take several minuts" -ForegroundColor Green
            Write-Host "Use Pipeline for a faster results, for example:" -ForegroundColor Green
            Write-Host " `"BTC`",`"ETH`" | Get-PSCCoinPrice" -ForegroundColor Yellow
            $CoinSym | Get-PSCCoinPrice 
          }
        Default {
            $AllCoinLatest=Invoke-RestMethod -Uri "https://min-api.cryptocompare.com/data/price?fsym=$($PSBoundParameters['CoinShortCode'])&tsyms=USD" -Method Get #-Headers $Header
            if ($AllCoinLatest.Response -like "Error"){
            return @{($PSBoundParameters['CoinShortCode'])= $AllCoinLatest.Message}}
            Else{
                return @{($PSBoundParameters['CoinShortCode'])= $AllCoinLatest.USD}}
            }
        }
    }
   
}


Function New-PSCCoinWalet {
# Specifies a path to one or more locations.
param(
[Parameter(Mandatory=$true)][string[]]$Path
)

}
Function New-PSCCoinAlert {
param(
    [parameter(Mandatory)]$CoinSymbol,
    [parameter(Mandatory)]$AlertOnPrice,
    [parameter(mandatory)]
    [ValidateSet("SMTP","WriteToFile")]
    $AltertViaChannel
)

}
