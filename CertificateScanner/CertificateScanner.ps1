<#PSScriptInfo
.VERSION 3.9.2.0
.GUID 163f0d06-5bef-4d9a-bf8b-0c353b92ffc0
.AUTHOR Faris Malaeb
.IMPROVEMENT Alessandro Tanino
.COMPANYNAME powershellcenter.com
.COPYRIGHT
.TAGS SSL, Certificate, Scan, Network, OS Detection, DNS
.LICENSEURI
.PROJECTURI https://www.powershellcenter.com/2021/12/23/sslexpirationcheck/
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
- Added -DnsServer parameter by user request. When used with -IncludeReverseDNS, this allows specifying a custom DNS server for all reverse lookup queries.
- Created a new robust helper function for reverse DNS lookups that uses Resolve-DnsName with an nslookup fallback.
- Integrated the custom DNS functionality across all scan types (Single, File, Network).
- Updated help and examples to reflect the new -DnsServer parameter.
.PRIVATEDATA
#>

<#
.SYNOPSIS
Comprehensive SSL/TLS Certificate Scanner with Network Discovery and OS Detection

.DESCRIPTION
Scan websites, IP addresses, or entire network ranges for SSL/TLS certificate details including expiration dates, 
issuer information, and subject details. Supports HTTPS and LDAPS protocols with optional OS detection and reverse DNS lookup.

Features:
- Single site scanning
- Bulk file-based scanning  
- Network range scanning with CIDR notation
- Parallel processing for network scans
- HTTPS and LDAPS certificate detection
- OS fingerprinting for certificate hosts
- Expiration filtering and monitoring
- CSV export with append functionality
- Email reporting capabilities
- Reverse DNS resolution (with optional custom DNS server)

.PARAMETER Examples
Display detailed usage examples and scenarios

.PARAMETER Help
Display this help information (alias: -?)

.EXAMPLE
.\CertificateScanner.ps1 -Examples
Display comprehensive usage examples

.EXAMPLE  
.\CertificateScanner.ps1 -Help
Display help and syntax information
#>

[CmdletBinding(DefaultParameterSetName='Help')]
param(
    # Core scanning parameters
    [Alias("FilePath")]
    [parameter(mandatory=$true,ParameterSetName="ReadFromFile")]$LoadFromFile,
    [parameter(mandatory=$true,ParameterSetName="Online")]$SiteToScan,
    [parameter(mandatory=$true,ParameterSetName="NetworkScan")]$Networks,
    
    # Common parameters for all scanning operations
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]
    [validateset("Tls","Tls11","Tls12","Ssl3","Default")]$ProtocolVersion='TLS12',
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]$SaveAsTo,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]$TimeoutSeconds=5,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]
    [switch]$IncludeReverseDNS,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]
    [string]$DnsServer,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]
    [int]$ExpiresInDays = $null,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]
    [switch]$GetOsType,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]
    [switch]$ExcludeExpired,
    
    # Email parameters (all scanning types support email)
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]$EmailSendTo,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]$EmailFrom,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]$EmailSMTPServer,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]$EmailSMTPServerPort="25",
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]
    [switch]$EmailSMTPServerSSL=$false,
    
    [parameter(ParameterSetName="ReadFromFile")]
    [parameter(ParameterSetName="Online")]
    [parameter(ParameterSetName="NetworkScan")]$EmailSubject,
    
    # Network scan specific parameters
    [parameter(ParameterSetName="NetworkScan")]$Port=443,
    [parameter(ParameterSetName="NetworkScan")]$AdditionalHTTPSPorts=@(),
    [parameter(ParameterSetName="NetworkScan")]$MaxThreads=10,
    [parameter(ParameterSetName="NetworkScan")][switch]$IncludeLDAPS=$false,
    [parameter(ParameterSetName="NetworkScan")][switch]$LDAPSOnly=$false,
    
    # Help parameters
    [parameter(ParameterSetName="Help")]
    [parameter(ParameterSetName="Examples")]
    [switch]$Examples,
    
    [parameter(ParameterSetName="Help")]
    [Alias("?")]
    [switch]$Help
)

Function Show-Help {
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════════════╗
║                          SSL/TLS Certificate Scanner v3.9.2.0                        ║
║                     Network Discovery & Certificate Analysis Tool                    ║
╚══════════════════════════════════════════════════════════════════════════════════════╝

SYNOPSIS
    Comprehensive SSL/TLS certificate scanner with network discovery, OS detection,
    and expiration monitoring capabilities.

SYNTAX
    # Single Site Scanning
    .\CertificateScanner.ps1 -SiteToScan <URL> [-ProtocolVersion <Protocol>] 
                              [-SaveAsTo <Path>] [-IncludeReverseDNS] [-DnsServer <IP>] 
                              [-GetOsType] [-ExpiresInDays <Days>]

    # Network Range Scanning  
    .\CertificateScanner.ps1 -Networks <CIDR> [-Port <Port>] [-MaxThreads <Count>]
                              [-AdditionalHTTPSPorts <Ports>] [-TimeoutSeconds <Seconds>]
                              [-IncludeLDAPS] [-LDAPSOnly] [-SaveAsTo <Path>]
                              [-IncludeReverseDNS] [-DnsServer <IP>] [-GetOsType] 
                              [-ExpiresInDays <Days>]

    # File-Based Scanning
    .\CertificateScanner.ps1 -LoadFromFile <FilePath> [-SaveAsTo <Path>]
                              [-IncludeReverseDNS] [-DnsServer <IP>] [-GetOsType] 
                              [-ExpiresInDays <Days>]

    # Email Reporting (any scan type)
    Add: -EmailSendTo <Email> -EmailFrom <Email> -EmailSMTPServer <Server>
         -EmailSubject <Subject> [-EmailSMTPServerPort <Port>] [-EmailSMTPServerSSL]

PARAMETERS
    -SiteToScan <String>         Target website or IP address (supports port notation)
    -Networks <String>           CIDR notation networks (comma-separated)
    -LoadFromFile <String>       File path containing list of URLs/IPs
    -Port <Int>                  Primary HTTPS port (default: 443)
    -AdditionalHTTPSPorts <Array> Additional HTTPS ports to scan
    -ProtocolVersion <String>    SSL/TLS version (Tls12, Tls11, Tls, Ssl3, Default)
    -TimeoutSeconds <Int>        Connection timeout in seconds (default: 5)
    -MaxThreads <Int>           Parallel scanning threads (default: 10)
    -ExpiresInDays <Int>        Filter certificates expiring in X days (0 = expired only)
    -ExcludeExpired              Exclude already expired certificates from results
    -SaveAsTo <String>          CSV output file (use +filename to append)
    -IncludeLDAPS               Include LDAPS (port 636) scanning
    -LDAPSOnly                  Scan only LDAPS certificates
    -IncludeReverseDNS          Perform reverse DNS lookups
    -DnsServer <String>         Optional: Custom DNS server for reverse lookups
    -GetOsType                  Detect operating system of certificate hosts
    -Examples                   Show detailed usage examples
    -Help, -?                   Show this help information

QUICK EXAMPLES
    # Basic website scan
    .\CertificateScanner.ps1 -SiteToScan www.google.com

    # Network scan with OS detection and custom DNS for lookups
    .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -GetOsType -IncludeReverseDNS -DnsServer 192.168.1.1 -SaveAsTo network_scan.csv

    # Find expiring certificates
    .\CertificateScanner.ps1 -Networks "10.0.0.0/16" -ExpiresInDays 30 -SaveAsTo +expiring.csv

    # LDAPS scan with email report
    .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -LDAPSOnly -EmailSendTo admin@company.com 
                              -EmailFrom scanner@company.com -EmailSMTPServer mail.company.com 
                              -EmailSubject "LDAPS Certificate Report"

For detailed examples and advanced scenarios, run: .\CertificateScanner.ps1 -Examples

"@ -ForegroundColor Cyan
}

Function Show-Examples {
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════════════╗
║                      Certificate Scanner - Usage Examples                           ║
╚══════════════════════════════════════════════════════════════════════════════════════╝

1. SINGLE SITE SCANNING
   ══════════════════════

   # Basic website scan
   .\CertificateScanner.ps1 -SiteToScan www.powershellcenter.com

   # Scan with custom port
   .\CertificateScanner.ps1 -SiteToScan mail.company.com:993

   # Scan with older SSL protocol
   .\CertificateScanner.ps1 -SiteToScan legacy.server.com -ProtocolVersion Ssl3

   # Comprehensive single site analysis with a specific internal DNS server
   .\CertificateScanner.ps1 -SiteToScan www.company.com -IncludeReverseDNS -DnsServer 10.1.1.1 -GetOsType -SaveAsTo site_analysis.csv

2. NETWORK SCANNING
   ══════════════════

   # Basic network scan
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24"

   # Multiple networks
   .\CertificateScanner.ps1 -Networks "10.10.2.0/24,10.2.4.0/24,172.20.3.0/22"

   # Large network with performance tuning
   .\CertificateScanner.ps1 -Networks "10.0.0.0/16" -MaxThreads 20 -TimeoutSeconds 3

   # Scan multiple HTTPS ports
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -Port 8443 -AdditionalHTTPSPorts 443,8080,9443

   # Complete network analysis with custom DNS
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -IncludeLDAPS -IncludeReverseDNS -DnsServer 192.168.1.1 -GetOsType -SaveAsTo full_scan.csv

3. FILE-BASED SCANNING
   ═══════════════════════

   # Create targets file first
   # echo "www.google.com`nwww.microsoft.com`nmail.company.com:993" > targets.txt

   # Scan from file
   .\CertificateScanner.ps1 -LoadFromFile targets.txt

   # File scan with comprehensive analysis and custom DNS
   .\CertificateScanner.ps1 -LoadFromFile critical_servers.txt -IncludeReverseDNS -DnsServer 10.5.5.1 -GetOsType -SaveAsTo server_certs.csv

4. EXPIRATION MONITORING
   ═══════════════════════

   # Find already expired certificates
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -ExpiresInDays 0

   # Find certificates expiring within 30 days
   .\CertificateScanner.ps1 -Networks "10.0.0.0/16" -ExpiresInDays 30 -SaveAsTo expiring_soon.csv

   # Weekly expiration check (90 days)
   .\CertificateScanner.ps1 -LoadFromFile production_servers.txt -ExpiresInDays 90 -SaveAsTo +weekly_check.csv

5. SAVING AND APPENDING RESULTS
   ══════════════════════════════

   # Save to new file
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -SaveAsTo network_certs.csv

   # Append to existing file (note the + prefix)
   .\CertificateScanner.ps1 -Networks "192.168.2.0/24" -SaveAsTo +network_certs.csv

   # Daily monitoring with date stamps
   `$date = Get-Date -Format "yyyy-MM-dd"
   .\CertificateScanner.ps1 -Networks "10.0.0.0/16" -ExpiresInDays 30 -SaveAsTo "daily_scan_`$date.csv"

6. LDAPS CERTIFICATE SCANNING
   ════════════════════════════

   # Include LDAPS in regular scan
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -IncludeLDAPS

   # Scan only LDAPS certificates
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -LDAPSOnly

   # LDAPS expiration monitoring
   .\CertificateScanner.ps1 -Networks "10.0.0.0/16" -LDAPSOnly -ExpiresInDays 60 -SaveAsTo ldaps_expiring.csv

7. ADVANCED SCENARIOS
   ═══════════════════

   # High-speed enterprise scan
   .\CertificateScanner.ps1 -Networks "10.0.0.0/8" -MaxThreads 50 -TimeoutSeconds 2 -Port 443 -AdditionalHTTPSPorts 8443,9443

   # Security audit with OS fingerprinting and custom DNS
   .\CertificateScanner.ps1 -Networks "192.168.0.0/16" -IncludeLDAPS -GetOsType -IncludeReverseDNS -DnsServer 10.10.10.254 -SaveAsTo security_audit.csv

   # Legacy system scan
   .\CertificateScanner.ps1 -LoadFromFile legacy_systems.txt -ProtocolVersion Ssl3 -TimeoutSeconds 10

8. EMAIL REPORTING
   ═════════════════

   # Basic email report
   .\CertificateScanner.ps1 -Networks "192.168.1.0/24" -ExpiresInDays 30 `
       -EmailSendTo admin@company.com `
       -EmailFrom certscanner@company.com `
       -EmailSMTPServer mail.company.com `
       -EmailSubject "Weekly Certificate Expiration Report"

   # Secure SMTP with SSL
   .\CertificateScanner.ps1 -SiteToScan critical.company.com -ExpiresInDays 7 `
       -EmailSendTo security@company.com `
       -EmailFrom alerts@company.com `
       -EmailSMTPServer smtp.gmail.com `
       -EmailSMTPServerPort 587 `
       -EmailSMTPServerSSL `
       -EmailSubject "URGENT: Certificate Expiring Soon"

9. MONITORING WORKFLOWS
   ═════════════════════

   # Daily expired certificate check
   .\CertificateScanner.ps1 -Networks "10.0.0.0/16" -ExpiresInDays 0 -SaveAsTo +expired_certs.csv
   if ((Import-Csv expired_certs.csv | Measure-Object).Count -gt 0) {
       # Send alert email
   }

   # Weekly comprehensive scan with archiving
   `$timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
   .\CertificateScanner.ps1 -Networks "192.168.0.0/16" -IncludeLDAPS -GetOsType `
       -SaveAsTo "weekly_scan_`$timestamp.csv"

   # Monthly expiration report
   `$nextMonth = (Get-Date).AddDays(30).ToString("yyyy-MM-dd")
   .\CertificateScanner.ps1 -LoadFromFile all_servers.txt -ExpiresInDays 30 `
       -EmailSendTo management@company.com `
       -EmailFrom certificates@company.com `
       -EmailSMTPServer internal-mail.company.com `
       -EmailSubject "Monthly Certificate Expiration Report - `$nextMonth"

10. PRO TIPS
    ════════

    # Performance optimization for large networks
    - Use MaxThreads between 10-50 (test optimal value for your network)
    - Reduce TimeoutSeconds to 2-3 for faster scans of responsive networks
    - Use specific port lists instead of scanning all default ports

    # Filtering and organization
    - Use ExpiresInDays 0 to find expired certificates immediately
    - Append mode (+filename) is perfect for scheduled monitoring
    - Combine with PowerShell filtering for advanced analysis:
      Import-Csv results.csv | Where-Object {`$_.Issuer -like "*Let's Encrypt*"}

    # Automation integration
    - Schedule with Task Scheduler or cron
    - Use exit codes: `$LASTEXITCODE will indicate scan success
    - Parse CSV results for integration with monitoring systems
    - Use email reports for immediate alerting

    # Troubleshooting
    - Use -ProtocolVersion Ssl3 for very old systems
    - Increase TimeoutSeconds for slow networks
    - Enable -IncludeReverseDNS for better host identification (use -DnsServer for internal networks)
    - Use -GetOsType for security auditing and system classification

For more information visit: https://www.powershellcenter.com

"@ -ForegroundColor Green
}

# Help system logic - check if help should be displayed
if ($PSCmdlet.ParameterSetName -eq 'Help' -or $Help -or $Examples -or ($PSBoundParameters.Count -eq 0)) {
    if ($Examples) {
        Show-Examples
    } else {
        Show-Help
    }
    return
}

Function Get-ReverseDnsName {
    param(
        [string]$IPAddress,
        [string]$DnsServer
    )

    try {
        if (-not ([string]::IsNullOrEmpty($DnsServer))) {
            # Custom DNS server specified
            # Use Resolve-DnsName as it's the modern, preferred method
            if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
                $result = Resolve-DnsName -Name $IPAddress -Type PTR -Server $DnsServer -DnsOnly -ErrorAction SilentlyContinue
                if ($result) {
                    # In case of multiple PTR records, return the first one
                    return ($result.NameHost | Select-Object -First 1)
                } else {
                    return "No PTR record (via $DnsServer)"
                }
            } else {
                # Fallback to nslookup if Resolve-DnsName is not available (e.g., older PowerShell)
                $nslookupResult = nslookup -type=PTR $IPAddress $DnsServer
                $ptrLine = $nslookupResult | Select-String -Pattern "name ="
                if ($ptrLine) {
                    # Output can be an array, take the first match
                    return (($ptrLine | Select-Object -First 1).ToString() -split '= ')[1].Trim()
                } else {
                     return "No PTR record (nslookup fallback)"
                }
            }
        } else {
            # Use system default DNS
            $hostEntry = [System.Net.Dns]::GetHostEntry($IPAddress)
            return $hostEntry.HostName
        }
    } catch {
        return "Reverse DNS Error: $($_.Exception.Message)"
    }
}

Function ConvertTo-IPRange {
    param(
        [string]$CIDR
    )

    $CIDR = $CIDR.Trim()
    $parts = $CIDR.Split('/')
    $ip = $parts[0]
    $subnet = [int]$parts[1]

    # Convert IP to integer
    $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
    [Array]::Reverse($ipBytes)
    $ipInt = [System.BitConverter]::ToUInt32($ipBytes, 0)

    # Calculate network range
    $mask = [Math]::Pow(2, 32 - $subnet) - 1
    $networkInt = $ipInt -band (-bnot $mask)
    $broadcastInt = $networkInt -bor $mask

    # Generate all IPs in range (excluding network and broadcast addresses for /24 and larger)
    $ips = @()
    $start = if ($subnet -ge 24) { $networkInt + 1 } else { $networkInt }
    $end = if ($subnet -ge 24) { $broadcastInt - 1 } else { $broadcastInt }

    for ($i = $start; $i -le $end; $i++) {
        $bytes = [System.BitConverter]::GetBytes($i)
        [Array]::Reverse($bytes)
        $ips += [System.Net.IPAddress]::new($bytes).ToString()
    }

    return $ips
}

Function Test-TCPPort {
    param(
        [string]$IPAddress,
        [int]$Port,
        [int]$TimeoutMs = 5000
    )

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($IPAddress, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if ($wait) {
            $tcpClient.EndConnect($asyncResult)
            $tcpClient.Close()
            return $true
        } else {
            $tcpClient.Close()
            return $false
        }
    }
    catch {
        if ($tcpClient) { $tcpClient.Close() }
        return $false
    }
}

Function Get-OSTypeFromHost {
    param(
        [string]$IPAddress,
        [int]$TimeoutMs = 3000
    )
    
    $osInfo = [PSCustomObject]@{
        OSType = "Unknown"
        OSDetails = ""
        DetectionMethod = ""
        Confidence = "Low"
    }
    
    try {
        # Method 1: TTL Analysis via ping
        $pingResult = Test-Connection -ComputerName $IPAddress -Count 1 -Quiet -TimeoutSeconds ($TimeoutMs/1000) -ErrorAction SilentlyContinue
        if ($pingResult) {
            # Get detailed ping info for TTL
            try {
                $pingDetails = Test-Connection -ComputerName $IPAddress -Count 1 -TimeoutSeconds ($TimeoutMs/1000) -ErrorAction SilentlyContinue
                if ($pingDetails -and $pingDetails.ResponseTime -ge 0) {
                    # Try to get TTL from ping
                    $ttl = $null
                    if ($pingDetails.PSObject.Properties.Name -contains "TimeToLive") {
                        $ttl = $pingDetails.TimeToLive
                    }
                    
                    if ($ttl) {
                        switch ($ttl) {
                            {$_ -le 64 -and $_ -gt 56} { 
                                $osInfo.OSType = "Linux/Unix"
                                $osInfo.OSDetails = "TTL: $ttl (Linux/Unix range)"
                                $osInfo.DetectionMethod = "TTL Analysis"
                                $osInfo.Confidence = "Medium"
                            }
                            {$_ -le 128 -and $_ -gt 120} { 
                                $osInfo.OSType = "Windows"
                                $osInfo.OSDetails = "TTL: $ttl (Windows range)"
                                $osInfo.DetectionMethod = "TTL Analysis"
                                $osInfo.Confidence = "Medium"
                            }
                            {$_ -le 255 -and $_ -gt 240} { 
                                $osInfo.OSType = "Network Device"
                                $osInfo.OSDetails = "TTL: $ttl (Network equipment range)"
                                $osInfo.DetectionMethod = "TTL Analysis"
                                $osInfo.Confidence = "Medium"
                            }
                        }
                    }
                }
            } catch {
                # TTL detection failed, continue with port analysis
            }
        }
        
        # Method 2: Port-based OS detection
        $portTests = @()
        
        # Test Windows-specific ports
        $windowsPorts = @(135, 139, 445, 3389) # RPC, NetBIOS, SMB, RDP
        $linuxPorts = @(22, 111, 2049) # SSH, RPC, NFS
        $webPorts = @(80, 8080, 8443) # Additional web ports
        
        $windowsPortsOpen = 0
        $linuxPortsOpen = 0
        $webPortsOpen = 0
        
        foreach ($port in $windowsPorts) {
            if (Test-TCPPort -IPAddress $IPAddress -Port $port -TimeoutMs 2000) {
                $windowsPortsOpen++
                $portTests += "Windows port $port"
            }
        }
        
        foreach ($port in $linuxPorts) {
            if (Test-TCPPort -IPAddress $IPAddress -Port $port -TimeoutMs 2000) {
                $linuxPortsOpen++
                $portTests += "Linux port $port"
            }
        }
        
        foreach ($port in $webPorts) {
            if (Test-TCPPort -IPAddress $IPAddress -Port $port -TimeoutMs 2000) {
                $webPortsOpen++
                $portTests += "Web port $port"
            }
        }
        
        # Determine OS based on port analysis (override TTL if more definitive)
        if ($windowsPortsOpen -ge 2) {
            $osInfo.OSType = "Windows"
            $osInfo.OSDetails = "Ports: " + ($portTests -join ', ')
            $osInfo.DetectionMethod = "Port Analysis"
            $osInfo.Confidence = "High"
        }
        elseif ($linuxPortsOpen -ge 1) {
            $osInfo.OSType = "Linux/Unix"
            $osInfo.OSDetails = "Ports: " + ($portTests -join ', ')
            $osInfo.DetectionMethod = "Port Analysis"
            $osInfo.Confidence = "High"
        }
        elseif ($windowsPortsOpen -eq 1 -and $linuxPortsOpen -eq 0) {
            $osInfo.OSType = "Likely Windows"
            $osInfo.OSDetails = "Ports: " + ($portTests -join ', ')
            $osInfo.DetectionMethod = "Port Analysis"
            $osInfo.Confidence = "Medium"
        }
        elseif ($webPortsOpen -gt 0 -and $windowsPortsOpen -eq 0 -and $linuxPortsOpen -eq 0) {
            $osInfo.OSType = "Web Server/Appliance"
            $osInfo.OSDetails = "Ports: " + ($portTests -join ', ')
            $osInfo.DetectionMethod = "Port Analysis"
            $osInfo.Confidence = "Medium"
        }
        
    } catch {
        $osInfo.OSDetails = "Error: $($_.Exception.Message)"
    }
    
    return $osInfo
}

Function Get-LDAPSCertificate {
    param(
        [string]$ServerName,
        [int]$Port = 636,
        [int]$TimeoutMs = 5000,
        [string]$ProtocolVersion = 'TLS12',
        [switch]$IncludeReverseDNS,
        [switch]$GetOsType,
        [string]$DnsServer
    )
    
    $reverseDNS = ""
    if ($IncludeReverseDNS) {
        $reverseDNS = Get-ReverseDnsName -IPAddress $ServerName -DnsServer $DnsServer
    }

    $results = [PSCustomObject]@{
        URL = $ServerName
        Port = $Port
        ServiceType = "LDAPS"
        StartDate = ''
        EndDate = ''
        Issuer = ''
        Subject = ''
        Protocol = $ProtocolVersion
        Status = "Unknown"
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        ReverseDNSName = $reverseDNS
        OSType = ''
        OSDetails = ''
        OSDetectionMethod = ''
        OSConfidence = ''
    }

    try {
        # Create TCP client with timeout
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($ServerName, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if (-not $wait) {
            $tcpClient.Close()
            throw "Connection timeout after $($TimeoutMs/1000) seconds"
        }
        
        $tcpClient.EndConnect($asyncResult)
        $networkStream = $tcpClient.GetStream()
        
        # Create SSL stream - LDAPS uses direct SSL/TLS connection
        $sslStream = New-Object System.Net.Security.SslStream($networkStream, $false, {
            param($sender, $certificate, $chain, $sslPolicyErrors)
            # Accept all certificates for scanning purposes
            $true
        })
        
        # Map protocol version string to enum
        $protocolEnum = switch ($ProtocolVersion) {
            'Ssl3' { [System.Security.Authentication.SslProtocols]::Ssl3 }
            'Tls' { [System.Security.Authentication.SslProtocols]::Tls }
            'Tls11' { [System.Security.Authentication.SslProtocols]::Tls11 }
            'Tls12' { [System.Security.Authentication.SslProtocols]::Tls12 }
            'Default' { [System.Security.Authentication.SslProtocols]::Default }
            default { [System.Security.Authentication.SslProtocols]::Tls12 }
        }
        
        # Authenticate as client (this establishes the SSL/TLS connection and exchanges certificates)
        $sslStream.AuthenticateAsClient($ServerName, $null, $protocolEnum, $false)
        
        # Extract certificate information
        if ($sslStream.RemoteCertificate) {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($sslStream.RemoteCertificate)
            
            $results.StartDate = $cert.NotBefore
            $results.EndDate = $cert.NotAfter
            $results.Issuer = $cert.Issuer
            $results.Subject = $cert.Subject
            $results.Status = 'Success'
        } else {
            throw "No certificate received from server"
        }
        
        # Clean up
        $sslStream.Close()
        $networkStream.Close()
        $tcpClient.Close()
        
        # Add OS detection after successful certificate scan
        if ($GetOsType -and $results.Status -eq 'Success') {
            $osInfo = Get-OSTypeFromHost -IPAddress $ServerName -TimeoutMs $TimeoutMs
            $results.OSType = $osInfo.OSType
            $results.OSDetails = $osInfo.OSDetails
            $results.OSDetectionMethod = $osInfo.DetectionMethod
            $results.OSConfidence = $osInfo.Confidence
        }
        
    } catch {
        $results.StartDate = $_.Exception.Message
        $results.EndDate = "LDAPS connection error. Check if LDAPS is enabled and certificate is valid."
        $results.Status = 'Error'
        
        # Clean up on error
        try { if ($sslStream) { $sslStream.Close() } } catch { }
        try { if ($networkStream) { $networkStream.Close() } } catch { }
        try { if ($tcpClient) { $tcpClient.Close() } } catch { }
    }
    
    return $results
}

Function ScanSiteInformaiton{
    param(
        $URLScanSiteInfo,
        $CustomPort = $null,
        $TimeoutMs = 5000,
        $ServiceType = "HTTPS",
        [switch]$IncludeReverseDNS,
        [switch]$GetOsType,
        [string]$DnsServer = $null,  # Fixed parameter name to match usage
        [int]$TimeoutSeconds = 5,
        [int]$ExpiresInDays = $null,
        [string]$ProtocolVersion = 'TLS12'
    )
    
    # Convert TimeoutSeconds to milliseconds if provided
    if ($PSBoundParameters.ContainsKey('TimeoutSeconds')) {
        $TimeoutMs = $TimeoutSeconds * 1000
    }
    
    # Clean up URL - remove protocol if present
    if ($URLScanSiteInfo -match '([a-z]+|[A-Z]+):\/\/'){
        $URLScanSiteInfo=$URLScanSiteInfo.Substring($Matches[0].Length)
    }
    
    # Remove trailing slash if present
    if ($URLScanSiteInfo -match '\/'){
        $URLScanSiteInfo=$URLScanSiteInfo.Substring(0,$URLScanSiteInfo.Length-1)
    }
    
    # Check for port notation (hostname:port) - FIXED REGEX
    if ($URLScanSiteInfo -match "^(.+?):(\d+)$") {
        $URLScanSite = $Matches[1]
        $PortToScan = [int]$Matches[2]
    } else {
        $URLScanSite = $URLScanSiteInfo
        $PortToScan = if ($CustomPort) { [int]$CustomPort } else { 443 }
    }

    $reverseDNS = ""
    if ($IncludeReverseDNS) {
        $reverseDNS = Get-ReverseDnsName -IPAddress $URLScanSite -DnsServer $DnsServer
    }

    # For LDAPS, use specialized function
    if ($ServiceType -eq "LDAPS" -or $PortToScan -eq 636) {
        return Get-LDAPSCertificate -ServerName $URLScanSite -Port $PortToScan -TimeoutMs $TimeoutMs -ProtocolVersion $ProtocolVersion -IncludeReverseDNS:$IncludeReverseDNS -GetOsType:$GetOsType -DnsServer $DnsServer
    }

    # Initialize results object outside the Try/Catch to ensure it's always available
    $results=[PSCustomObject]@{
        URL=$URLScanSiteInfo
        Port=$PortToScan
        ServiceType=$ServiceType
        StartDate=''
        EndDate=''
        Issuer=''
        Subject=''
        Protocol=$ProtocolVersion
        Status="Unknown"
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        ReverseDNSName = $reverseDNS
        DNSServer = if ($DnsServer) { $DnsServer } else { "System DNS" }
        OSType = ''
        OSDetails = ''
        OSDetectionMethod = ''
        OSConfidence = ''
        DaysUntilExpiration = $null
        ExpirationStatus = ''
    }

    Try{
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

        # Add timeout for socket connection
        $socket = New-Object Net.Sockets.TcpClient
        $asyncResult = $socket.BeginConnect($URLScanSite, $PortToScan, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if (-not $wait) {
            $socket.Close()
            throw "Connection timeout after $($TimeoutMs/1000) seconds"
        }

        $socket.EndConnect($asyncResult)

        $stream = $socket.GetStream()
        $sslStream = New-Object System.Net.Security.SslStream($stream, $false, ({ $True } -as [Net.Security.RemoteCertificateValidationCallback]))
        
        # Map protocol version string to enum - FIXED MAPPING
        $protocolEnum = switch ($ProtocolVersion) {
            'Ssl3' { [System.Security.Authentication.SslProtocols]::Ssl3 }
            'Tls' { [System.Security.Authentication.SslProtocols]::Tls }
            'Tls11' { [System.Security.Authentication.SslProtocols]::Tls11 }
            'Tls12' { [System.Security.Authentication.SslProtocols]::Tls12 }
            'Default' { [System.Security.Authentication.SslProtocols]::Default }
            default { [System.Security.Authentication.SslProtocols]::Tls12 }
        }
        
        $sslStream.AuthenticateAsClient($URLScanSite, $null, $protocolEnum, $false)

        # Populate certificate details
        $results.StartDate = $sslStream.RemoteCertificate.NotBefore
        $results.EndDate = $sslStream.RemoteCertificate.NotAfter
        $results.Issuer=$sslStream.RemoteCertificate.Issuer
        $results.Subject=$sslStream.RemoteCertificate.Subject
        $results.Status = "Success"

        # Calculate days until expiration if ExpiresInDays parameter was provided
        if ($PSBoundParameters.ContainsKey('ExpiresInDays')) {
            $today = (Get-Date).Date
            $certEndDate = [datetime]$sslStream.RemoteCertificate.NotAfter
            $daysUntilExpiration = ($certEndDate.Date - $today).Days
            $results.DaysUntilExpiration = $daysUntilExpiration
            
            # Set expiration status
            if ($daysUntilExpiration -lt 0) {
                $results.ExpirationStatus = "EXPIRED"
            } elseif ($daysUntilExpiration -le $ExpiresInDays) {
                $results.ExpirationStatus = "EXPIRING SOON"
            } else {
                $results.ExpirationStatus = "OK"
            }
        }

        $socket.close()
        
        # Add OS detection after successful certificate scan
        if ($GetOsType -and $results.Status -eq "Success") {
            Write-Host "Detecting OS for $URLScanSite..." -ForegroundColor Yellow
            $osInfo = Get-OSTypeFromHost -IPAddress $URLScanSite -TimeoutMs $TimeoutMs
            $results.OSType = $osInfo.OSType
            $results.OSDetails = $osInfo.OSDetails
            $results.OSDetectionMethod = $osInfo.DetectionMethod
            $results.OSConfidence = $osInfo.Confidence
            
            if ($osInfo.OSType -ne "Unknown") {
                Write-Host "  OS detected: $($osInfo.OSType) ($($osInfo.Confidence) confidence)" -ForegroundColor Green
            }
        }
    }
    Catch{
        Write-Host "$($URLScanSiteInfo):$($PortToScan) - " -NoNewline -ForegroundColor Red; Write-Host "ERROR: $($_.Exception.Message)"
        $results.StartDate=$_.Exception.Message
        $results.EndDate="Connection or protocol error. Try using a different -ProtocolVersion."
        $results.Status = "Error"
    }

    # Apply expiration filtering if ExpiresInDays was specified
    if ($PSBoundParameters.ContainsKey('ExpiresInDays') -and $results.Status -eq "Success") {
        $today = (Get-Date).Date
        $certEndDate = [datetime]$results.EndDate
        $daysUntilExpiration = ($certEndDate.Date - $today).Days
        
        # Only return results that meet the expiration criteria
        if ($ExpiresInDays -eq 0) {
            # Show only expired certificates
            if ($daysUntilExpiration -ge 0) {
                return $null # Certificate not expired, don't return it
            }
        } else {
            # Show certificates expiring within specified days
            if ($daysUntilExpiration -gt $ExpiresInDays) {
                return $null # Certificate expires too far in the future, don't return it
            }
        }
    }

    Return $results
}

# Example usage:
# ScanSiteInformaiton -URLScanSiteInfo "example.com" -IncludeReverseDNS -DNSServer "10.185.16.4" -GetOsType -TimeoutSeconds 4 -ExpiresInDays 60

# You'll also need this helper function for reverse DNS lookups:
Function Get-ReverseDnsName {
    param(
        [string]$IPAddress,
        [string]$DnsServer = $null
    )
    
    try {
        if ($DnsServer) {
            # Use specified DNS server
            $result = Resolve-DnsName -Name $IPAddress -Server $DnsServer -Type PTR -ErrorAction Stop -DnsOnly
            if ($result -and $result.NameHost) {
                return $result.NameHost
            }
        } else {
            # Use system DNS
            $hostEntry = [System.Net.Dns]::GetHostEntry($IPAddress)
            return $hostEntry.HostName
        }
    }
    catch {
        return "DNS lookup failed: $($_.Exception.Message)"
    }
    
    return "No reverse DNS record found"
}

Function Invoke-ParallelScan {
    param(
        [array]$IPList,
        [array]$PortList,
        [int]$MaxThreads,
        [int]$TimeoutMs,
        [string]$ProtocolVersion,
        [switch]$IncludeReverseDNS,
        [switch]$GetOsType,
        [string]$DnsServer
    )

    # Create runspace pool
    $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
    $RunspacePool.Open()

    # Create script block for scanning
    $ScriptBlock = {
        param($IP, $Port, $TimeoutMs, $ProtocolVersion, $IncludeReverseDNS, $GetOsType, $DnsServer)

        # Define functions inside the script block since runspaces dont inherit them
        Function Get-ReverseDnsNameInternal {
            param(
                [string]$IPAddress,
                [string]$DnsServer
            )
            try {
                if (-not ([string]::IsNullOrEmpty($DnsServer))) {
                    if (Get-Command Resolve-DnsName -ErrorAction SilentlyContinue) {
                        $result = Resolve-DnsName -Name $IPAddress -Type PTR -Server $DnsServer -DnsOnly -ErrorAction SilentlyContinue
                        if ($result) {
                            return ($result.NameHost | Select-Object -First 1)
                        } else {
                            return "No PTR record (via $DnsServer)"
                        }
                    } else {
                        $nslookupResult = nslookup -type=PTR $IPAddress $DnsServer
                        $ptrLine = $nslookupResult | Select-String -Pattern "name ="
                        if ($ptrLine) {
                            return (($ptrLine | Select-Object -First 1).ToString() -split '= ')[1].Trim()
                        } else {
                            return "No PTR record (nslookup fallback)"
                        }
                    }
                } else {
                    $hostEntry = [System.Net.Dns]::GetHostEntry($IPAddress)
                    return $hostEntry.HostName
                }
            } catch {
                return "Reverse DNS Error: $($_.Exception.Message)"
            }
        }

        Function Test-TCPPortInternal {
            param([string]$IPAddress, [int]$Port, [int]$TimeoutMs)
            try {
                $tcpClient = New-Object System.Net.Sockets.TcpClient
                $asyncResult = $tcpClient.BeginConnect($IPAddress, $Port, $null, $null)
                $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
                if ($wait) {
                    $tcpClient.EndConnect($asyncResult)
                    $tcpClient.Close()
                    return $true
                } else {
                    $tcpClient.Close()
                    return $false
                }
            }
            catch {
                if ($tcpClient) { $tcpClient.Close() }
                return $false
            }
        }

        Function Get-OSTypeFromHostInternal {
            param([string]$IPAddress, [int]$TimeoutMs = 3000)
            
            $osInfo = [PSCustomObject]@{
                OSType = "Unknown"
                OSDetails = ""
                DetectionMethod = ""
                Confidence = "Low"
            }
            
            try {
                # Port-based OS detection (simplified for parallel execution)
                $windowsPorts = @(135, 139, 445, 3389)
                $linuxPorts = @(22, 111)
                
                $windowsPortsOpen = 0
                $linuxPortsOpen = 0
                $portTests = @()
                
                foreach ($port in $windowsPorts) {
                    if (Test-TCPPortInternal -IPAddress $IPAddress -Port $port -TimeoutMs 1500) {
                        $windowsPortsOpen++
                        $portTests += "Win:$port"
                    }
                }
                
                foreach ($port in $linuxPorts) {
                    if (Test-TCPPortInternal -IPAddress $IPAddress -Port $port -TimeoutMs 1500) {
                        $linuxPortsOpen++
                        $portTests += "Nix:$port"
                    }
                }
                
                if ($windowsPortsOpen -ge 2) {
                    $osInfo.OSType = "Windows"
                    $osInfo.OSDetails = $portTests -join ','
                    $osInfo.DetectionMethod = "Port Analysis"
                    $osInfo.Confidence = "High"
                }
                elseif ($linuxPortsOpen -ge 1) {
                    $osInfo.OSType = "Linux/Unix"
                    $osInfo.OSDetails = $portTests -join ','
                    $osInfo.DetectionMethod = "Port Analysis"
                    $osInfo.Confidence = "High"
                }
                elseif ($windowsPortsOpen -eq 1) {
                    $osInfo.OSType = "Likely Windows"
                    $osInfo.OSDetails = $portTests -join ","
                    $osInfo.DetectionMethod = "Port Analysis"
                    $osInfo.Confidence = "Medium"
                }
            } catch {
                $osInfo.OSDetails = "OS detection error"
            }
            
            return $osInfo
        }

        Function Get-LDAPSCertificateInternal {
    param(
        [string]$ServerName,
        [int]$Port = 636,
        [int]$TimeoutMs = 5000,
        [string]$ProtocolVersion = "TLS12",
        [switch]$IncludeReverseDNS,
        [switch]$GetOsType,
        [string]$DnsServer
    )
    
    $reverseDNS = ""
    if ($IncludeReverseDNS) {
        $reverseDNS = Get-ReverseDnsNameInternal -IPAddress $ServerName -DnsServer $DnsServer
    }

    $results = [PSCustomObject]@{
        URL = $ServerName
        Port = $Port
        ServiceType = "LDAPS"
        StartDate = ''
        EndDate = ''
        Issuer = ''
        Subject = ''
        Protocol = $ProtocolVersion
        Status = "Unknown"
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        ReverseDNSName = $reverseDNS
        OSType = ''
        OSDetails = ''
        OSDetectionMethod = ''
        OSConfidence = ''
        DaysUntilExpiration = $null
        ExpirationStatus = ''
    }

    try {
        # Create TCP client with timeout
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcpClient.BeginConnect($ServerName, $Port, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if (-not $wait) {
            $tcpClient.Close()
            throw "Connection timeout after $($TimeoutMs/1000) seconds"
        }
        
        $tcpClient.EndConnect($asyncResult)
        $networkStream = $tcpClient.GetStream()
        
        # Create SSL stream - LDAPS uses direct SSL/TLS connection
        $sslStream = New-Object System.Net.Security.SslStream($networkStream, $false, {
            param($sender, $certificate, $chain, $sslPolicyErrors)
            # Accept all certificates for scanning purposes
            $true
        })
        
        # Map protocol version string to enum
        $protocolEnum = switch ($ProtocolVersion) {
            "Ssl3" { [System.Security.Authentication.SslProtocols]::Ssl3 }
            "Tls" { [System.Security.Authentication.SslProtocols]::Tls }
            "Tls11" { [System.Security.Authentication.SslProtocols]::Tls11 }
            "Tls12" { [System.Security.Authentication.SslProtocols]::Tls12 }
            "Default" { [System.Security.Authentication.SslProtocols]::Default }
            default { [System.Security.Authentication.SslProtocols]::Tls12 }
        }
        
        # Authenticate as client (this establishes the SSL/TLS connection and exchanges certificates)
        $sslStream.AuthenticateAsClient($ServerName, $null, $protocolEnum, $false)
        
        # Extract certificate information
        if ($sslStream.RemoteCertificate) {
            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($sslStream.RemoteCertificate)
            
            $results.StartDate = $cert.NotBefore
            $results.EndDate = $cert.NotAfter
            $results.Issuer = $cert.Issuer
            $results.Subject = $cert.Subject
            $results.Status = "Success"
            
            # Calculate expiration information
            $today = (Get-Date).Date
            $certEndDate = [datetime]$cert.NotAfter
            $daysUntilExpiration = ($certEndDate.Date - $today).Days
            $results.DaysUntilExpiration = $daysUntilExpiration
            
            if ($daysUntilExpiration -lt 0) {
                $results.ExpirationStatus = "EXPIRED"
            } else {
                $results.ExpirationStatus = "OK"
            }
        } else {
            throw "No certificate received from server"
        }
        
        # Clean up
        $sslStream.Close()
        $networkStream.Close()
        $tcpClient.Close()
        
        # Add OS detection after successful certificate scan
        if ($GetOsType -and $results.Status -eq "Success") {
            $osInfo = Get-OSTypeFromHostInternal -IPAddress $ServerName -TimeoutMs $TimeoutMs
            $results.OSType = $osInfo.OSType
            $results.OSDetails = $osInfo.OSDetails
            $results.OSDetectionMethod = $osInfo.DetectionMethod
            $results.OSConfidence = $osInfo.Confidence
        }
        
    } catch {
        $results.StartDate = $_.Exception.Message
        $results.EndDate = "LDAPS connection error. Check if LDAPS is enabled and certificate is valid."
        $results.Status = "Error"
        
        # Clean up on error
        try { if ($sslStream) { $sslStream.Close() } } catch { }
        try { if ($networkStream) { $networkStream.Close() } } catch { }
        try { if ($tcpClient) { $tcpClient.Close() } } catch { }
    }
    
    return $results
}

Function ScanSiteInformaitonInternal {
    param($URLScanSiteInfo, $CustomPort, $TimeoutMs, $ServiceType, $ProtocolVersion, [switch]$IncludeReverseDNS, [switch]$GetOsType, [string]$DnsServer)

    $reverseDNS = ""
    if ($IncludeReverseDNS) {
        $reverseDNS = Get-ReverseDnsNameInternal -IPAddress $URLScanSiteInfo -DnsServer $DnsServer
    }

    # For LDAPS, use specialized function
    if ($ServiceType -eq "LDAPS" -or $CustomPort -eq 636) {
        return Get-LDAPSCertificateInternal -ServerName $URLScanSiteInfo -Port $CustomPort -TimeoutMs $TimeoutMs -ProtocolVersion $ProtocolVersion -IncludeReverseDNS:$IncludeReverseDNS -GetOsType:$GetOsType -DnsServer $DnsServer
    }

    $results = [PSCustomObject]@{
        URL = $URLScanSiteInfo
        Port = $CustomPort
        ServiceType = $ServiceType
        StartDate = ''
        EndDate = ''
        Issuer = ''
        Subject = ''
        Protocol = $ProtocolVersion
        Status = "Unknown"
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        ReverseDNSName = $reverseDNS
        OSType = ''
        OSDetails = ''
        OSDetectionMethod = ''
        OSConfidence = ''
        DaysUntilExpiration = $null
        ExpirationStatus = ''
    }

    Try {
        [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

        $socket = New-Object Net.Sockets.TcpClient
        $asyncResult = $socket.BeginConnect($URLScanSiteInfo, $CustomPort, $null, $null)
        $wait = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if (-not $wait) {
            $socket.Close()
            throw "Connection timeout after $($TimeoutMs/1000) seconds"
        }

        $socket.EndConnect($asyncResult)

        $stream = $socket.GetStream()
        $sslStream = New-Object System.Net.Security.SslStream($stream, $false, ({ $True } -as [Net.Security.RemoteCertificateValidationCallback]))
        
        # Map protocol version correctly
        $protocolEnum = switch ($ProtocolVersion) {
            'Ssl3' { [System.Security.Authentication.SslProtocols]::Ssl3 }
            'Tls' { [System.Security.Authentication.SslProtocols]::Tls }
            'Tls11' { [System.Security.Authentication.SslProtocols]::Tls11 }
            'Tls12' { [System.Security.Authentication.SslProtocols]::Tls12 }
            'Default' { [System.Security.Authentication.SslProtocols]::Default }
            default { [System.Security.Authentication.SslProtocols]::Tls12 }
        }
        
        $sslStream.AuthenticateAsClient($URLScanSiteInfo, $null, $protocolEnum, $false)

        $results.StartDate = $sslStream.RemoteCertificate.NotBefore
        $results.EndDate = $sslStream.RemoteCertificate.NotAfter
        $results.Issuer = $sslStream.RemoteCertificate.Issuer
        $results.Subject = $sslStream.RemoteCertificate.Subject
        $results.Status = "Success"

        # Calculate expiration information
        $today = (Get-Date).Date
        $certEndDate = [datetime]$sslStream.RemoteCertificate.NotAfter
        $daysUntilExpiration = ($certEndDate.Date - $today).Days
        $results.DaysUntilExpiration = $daysUntilExpiration
        
        if ($daysUntilExpiration -lt 0) {
            $results.ExpirationStatus = "EXPIRED"
        } else {
            $results.ExpirationStatus = "OK"
        }

        $socket.close()
        
        # Add OS detection after successful certificate scan
        if ($GetOsType -and $results.Status -eq "Success") {
            $osInfo = Get-OSTypeFromHostInternal -IPAddress $URLScanSiteInfo -TimeoutMs $TimeoutMs
            $results.OSType = $osInfo.OSType
            $results.OSDetails = $osInfo.OSDetails
            $results.OSDetectionMethod = $osInfo.DetectionMethod
            $results.OSConfidence = $osInfo.Confidence
        }
    }
    Catch {
        $results.StartDate = $_.Exception.Message
        $results.EndDate = "Connection or protocol error. Try using a different -ProtocolVersion."
        $results.Status = "Error"
    }

    Return $results
}
        # Main scanning logic
        $serviceType = if ($Port -eq 636) { "LDAPS" } else { "HTTPS" }

        if (Test-TCPPortInternal -IPAddress $IP -Port $Port -TimeoutMs $TimeoutMs) {
            return ScanSiteInformaitonInternal -URLScanSiteInfo $IP -CustomPort $Port -TimeoutMs $TimeoutMs -ServiceType $serviceType -ProtocolVersion $ProtocolVersion -IncludeReverseDNS:$IncludeReverseDNS -GetOsType:$GetOsType -DnsServer $DnsServer
        } else {
            $reverseDNS = ""
            if ($IncludeReverseDNS) {
                $reverseDNS = Get-ReverseDnsNameInternal -IPAddress $IP -DnsServer $DnsServer
            }
            return [PSCustomObject]@{
                URL = $IP
                Port = $Port
                ServiceType = $serviceType
                StartDate = "Port Closed"
                EndDate = "Port closed or filtered"
                Issuer = ''
                Subject = ''
                Protocol = $ProtocolVersion
                Status = "Port Closed"
                ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
                ReverseDNSName = $reverseDNS
                OSType = ''
                OSDetails = ''
                OSDetectionMethod = ''
                OSConfidence = ''
            }
        }
    }

    # Create jobs for each IP/Port combination
    $Jobs = @()
    foreach ($ip in $IPList) {
        foreach ($port in $PortList) {
            $PowerShell = [powershell]::Create()
            $PowerShell.RunspacePool = $RunspacePool
            [void]$PowerShell.AddScript($ScriptBlock)
            [void]$PowerShell.AddParameter("IP", $ip)
            [void]$PowerShell.AddParameter("Port", $port)
            [void]$PowerShell.AddParameter("TimeoutMs", $TimeoutMs)
            [void]$PowerShell.AddParameter("ProtocolVersion", $ProtocolVersion)
            [void]$PowerShell.AddParameter("IncludeReverseDNS", $IncludeReverseDNS)
            [void]$PowerShell.AddParameter("GetOsType", $GetOsType)
            [void]$PowerShell.AddParameter("DnsServer", $DnsServer)

            $Jobs += [PSCustomObject]@{
                PowerShell = $PowerShell
                Handle = $PowerShell.BeginInvoke()
                IP = $ip
                Port = $port
            }
        }
    }

    # Wait for jobs to complete and collect results
    $Results = @()
    $CompletedJobs = 0
    $TotalJobs = $Jobs.Count

    Write-Host "Started $TotalJobs parallel scanning jobs using $MaxThreads threads..." -ForegroundColor Green

    do {
        Start-Sleep -Milliseconds 500

        $CompletedCount = ($Jobs | Where-Object { $_.Handle.IsCompleted }).Count
        if ($CompletedCount -gt $CompletedJobs) {
            $CompletedJobs = $CompletedCount
            Write-Progress -Activity "Parallel Network Scanning" -Status "Completed $CompletedJobs of $TotalJobs scans" -PercentComplete (($CompletedJobs / $TotalJobs) * 100)
        }

        # Collect completed results
        $CompletedJobs_ToProcess = $Jobs | Where-Object { $_.Handle.IsCompleted -and $_.PowerShell.InvocationStateInfo.State -eq "Completed" }
        foreach ($job in $CompletedJobs_ToProcess) {
            try {
                $result = $job.PowerShell.EndInvoke($job.Handle)
                if ($result) {
                    $Results += $result
                    if ($result.Status -eq "Success") {
                        $osInfo = if ($GetOsType -and $result.OSType) { " [OS: $($result.OSType)]" } else { "" }
                        Write-Host "✓ $($result.URL):$($result.Port) ($($result.ServiceType)) - Certificate found$osInfo" -ForegroundColor Green
                        if ($IncludeReverseDNS -and $result.ReverseDNSName) {
                            Write-Host "  Reverse DNS: $($result.ReverseDNSName)" -ForegroundColor DarkGreen
                        }
                    }
                }
            }
            catch {
                Write-Host "✗ $($job.IP):$($job.Port) - Job error: $($_.Exception.Message)" -ForegroundColor Red
            }
            finally {
                $job.PowerShell.Dispose()
            }
        }

        # Remove completed jobs from the list
        $Jobs = $Jobs | Where-Object { -not $_.Handle.IsCompleted -or $_.PowerShell.InvocationStateInfo.State -ne "Completed" }

    } while ($Jobs.Count -gt 0)

    Write-Progress -Activity "Parallel Network Scanning" -Completed
    $RunspacePool.Close()
    $RunspacePool.Dispose()

    return $Results
}

Function Apply-ExpirationFilter {
    param(
        [array]$Results,
        [int]$ExpiresInDays,
        [switch]$ExcludeExpired
    )
    
    if ($null -eq $Results -or $Results.Count -eq 0) {
        return @()
    }
    
    $Today = (Get-Date).Date
    $filteredResults = @()
    
    foreach ($result in $Results) {
        # Skip non-successful results
        if ($result.Status -ne "Success") {
            continue
        }
        
        # Parse EndDate - it might be a string or datetime
        $endDate = $null
        try {
            if ($result.EndDate -is [datetime]) {
                $endDate = $result.EndDate
            } elseif ($result.EndDate -is [string] -and $result.EndDate -ne "") {
                $endDate = [datetime]::Parse($result.EndDate)
            } else {
                continue  # Skip if we can't parse the date
            }
        } catch {
            Write-Warning "Could not parse EndDate '$($result.EndDate)' for $($result.URL):$($result.Port)"
            continue
        }
        
        # Calculate days until expiration
        $daysUntilExpiration = ($endDate.Date - $Today).Days
        
        # Add expiration info to the result object
        $result | Add-Member -Name "DaysUntilExpiration" -Value $daysUntilExpiration -MemberType NoteProperty -Force
        
        if ($daysUntilExpiration -lt 0) {
            $result | Add-Member -Name "ExpirationStatus" -Value "EXPIRED" -MemberType NoteProperty -Force
        } elseif ($daysUntilExpiration -le $ExpiresInDays) {
            $result | Add-Member -Name "ExpirationStatus" -Value "EXPIRING SOON" -MemberType NoteProperty -Force
        } else {
            $result | Add-Member -Name "ExpirationStatus" -Value "OK" -MemberType NoteProperty -Force
        }
        
        # Apply filtering logic
        $shouldInclude = $false
        
        if ($ExcludeExpired -and $daysUntilExpiration -lt 0) {
            # Exclude expired certificates
            $shouldInclude = $false
        } elseif ($ExpiresInDays -eq 0) {
            # Show only expired certificates
            $shouldInclude = ($daysUntilExpiration -lt 0)
        } else {
            # Show certificates expiring within specified days (including expired if not excluded)
            if ($ExcludeExpired) {
                $shouldInclude = ($daysUntilExpiration -ge 0 -and $daysUntilExpiration -le $ExpiresInDays)
            } else {
                $shouldInclude = ($daysUntilExpiration -le $ExpiresInDays)
            }
        }
        
        if ($shouldInclude) {
            $filteredResults += $result
        }
    }
    
    # Display filtering summary
    if ($ExcludeExpired) {
        Write-Host "Excluded already expired certificates from results." -ForegroundColor Yellow
    }
    
    if ($ExpiresInDays -eq 0) {
        Write-Host "Filtered to show only already expired certificates: $($filteredResults.Count) found." -ForegroundColor Yellow
    } else {
        Write-Host "Filtered to show certificates expiring within $ExpiresInDays days: $($filteredResults.Count) found." -ForegroundColor Yellow
    }
    
    return $filteredResults
}


Function Save-Results {
    param(
        [array]$Results,
        [string]$SaveAsTo
    )
    # Check if Results is null or empty - do nothing if so
    if ($null -eq $Results -or $Results.Count -eq 0) {
        Write-Host "No results to save (Results is null or empty)" -ForegroundColor Yellow
        return
    }
    try {
        # Check if filename starts with + for append mode
        $appendMode = $SaveAsTo.StartsWith("+")
        $actualFileName = if ($appendMode) { $SaveAsTo.Substring(1) } else { $SaveAsTo }
        
        if ($appendMode -and (Test-Path $actualFileName)) {
            # Append mode: add to existing file with -Force to handle column mismatches
            $Results | Export-Csv -Path $actualFileName -NoTypeInformation -Append -Force
            Write-Host "Results appended to: $actualFileName" -ForegroundColor Green
        } else {
            # Normal mode: create new file or overwrite existing
            $Results | Export-Csv -Path $actualFileName -NoTypeInformation
            if ($appendMode) {
                Write-Host "Results saved to new file: $actualFileName (file didn't exist for append)" -ForegroundColor Green
            } else {
                Write-Host "Results saved to: $actualFileName" -ForegroundColor Green
            }
        }
    }
    catch {
        Throw $_.Exception.Message
    }
}

Function SendMailToTheInternet {
    param(
        $Fullresult,
        $EmailFrom,
        $EmailSendTo,
        $EmailSubject,
        $EmailSMTPServer,
        $EmailSMTPServerPort,
        [switch]$EmailSMTPServerSSL
    )
    try{
        $SendMail=@{
            From=$EmailFrom
            To =$EmailSendTo
            Subject =$EmailSubject
            Body =($Fullresult | Out-String)
            SmtpServer =$EmailSMTPServer
            Credential =(Get-Credential)
            Port= $EmailSMTPServerPort
            UseSsl = $EmailSMTPServerSSL
        }
        Write-Host "Sending Email ...[][][]"
        Send-MailMessage @sendmail
        Write-Host "Email Sent ...>>>>"
    }
    Catch{
        Throw $_.exception.message
    }
}

## Start for Network Scan
if ($PSCmdlet.ParameterSetName -eq "NetworkScan") {
    Write-Host "Starting network scan..." -ForegroundColor Green
    $Fullresult = @()
    $allIPs = @()

    # Determine which ports to scan
    $portsToScan = @()
    $httpsPortsToScan = @()

    # Build HTTPS ports list
    $httpsPortsToScan += $Port  # Always include the main port
    if ($AdditionalHTTPSPorts.Count -gt 0) {
        $httpsPortsToScan += $AdditionalHTTPSPorts
    }
    # Remove duplicates
    $httpsPortsToScan = $httpsPortsToScan | Sort-Object | Get-Unique

    if ($LDAPSOnly) {
        $portsToScan = @(636)
        Write-Host "Scanning LDAPS certificates only (port 636)" -ForegroundColor Cyan
    } elseif ($IncludeLDAPS) {
        $portsToScan = @($httpsPortsToScan) + 636
        Write-Host "Scanning HTTPS ports ($($httpsPortsToScan -join ", ")) and LDAPS (port 636)" -ForegroundColor Cyan
    } else {
        $portsToScan = $httpsPortsToScan
        Write-Host "Scanning HTTPS ports: $($httpsPortsToScan -join ", ")" -ForegroundColor Cyan
    }

    # Parse multiple networks
    $networkList = $Networks.Split(",").Trim()

    foreach ($network in $networkList) {
        Write-Host "Processing network: $network" -ForegroundColor Yellow
        try {
            $ips = ConvertTo-IPRange -CIDR $network
            $allIPs += $ips
            Write-Host "Generated $($ips.Count) IP addresses from $network" -ForegroundColor Cyan
        }
        catch {
            Write-Host "Error processing network $network : $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host "Total IP addresses to scan: $($allIPs.Count)" -ForegroundColor Green
    Write-Host "Total ports per IP: $($portsToScan.Count) with timeout $TimeoutSeconds seconds..." -ForegroundColor Green
    Write-Host "Using $MaxThreads concurrent threads for parallel scanning..." -ForegroundColor Green
    if ($IncludeReverseDNS) {
        if($DnsServer) {
            Write-Host "Reverse DNS lookup enabled (using custom server: $DnsServer)." -ForegroundColor Green
        } else {
            Write-Host "Reverse DNS lookup enabled (using system DNS)." -ForegroundColor Green
        }
    }
    if ($GetOsType) {
        Write-Host "OS detection enabled for hosts with certificates." -ForegroundColor Green
    }
    if ($PSBoundParameters.ContainsKey("ExpiresInDays")) {
        if ($ExpiresInDays -eq 0) {
            Write-Host "Will show only already expired certificates." -ForegroundColor Yellow
        } else {
            Write-Host "Will show certificates expiring in $ExpiresInDays days or less." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Will show all certificates found (no expiration filtering)." -ForegroundColor Green
    }

    # Use parallel scanning
    $Fullresult = Invoke-ParallelScan -IPList $allIPs -PortList $portsToScan -MaxThreads $MaxThreads -TimeoutMs ($TimeoutSeconds * 1000) -ProtocolVersion $ProtocolVersion -IncludeReverseDNS:$IncludeReverseDNS -GetOsType:$GetOsType -DnsServer $DnsServer

    # Apply expiration filter only if ExpiresInDays parameter was explicitly provided
    if ($PSBoundParameters.ContainsKey("ExpiresInDays") -or $ExcludeExpired) {
        $Fullresult = Apply-ExpirationFilter -Results $Fullresult -ExpiresInDays $ExpiresInDays -ExcludeExpired:$ExcludeExpired
    }

    # Filter out port closed results for cleaner output
    $SuccessfulResults = $Fullresult | Where-Object { $_.Status -eq "Success" }
    $ErrorResults = $Fullresult | Where-Object { $_.Status -ne "Success" -and $_.Status -ne "Port Closed" }
    $PortClosedResults = $Fullresult | Where-Object { $_.Status -eq "Port Closed" }

    Write-Host "Network scan completed in parallel!" -ForegroundColor Green

    # Display summary by service type and port
    $httpsCount = ($SuccessfulResults | Where-Object { $_.ServiceType -eq "HTTPS" }).Count
    $ldapsCount = ($SuccessfulResults | Where-Object { $_.ServiceType -eq "LDAPS" }).Count
    $portClosedCount = $PortClosedResults.Count
    $errorCount = $ErrorResults.Count

    Write-Host "Summary: $httpsCount HTTPS certificates, $ldapsCount LDAPS certificates found, $portClosedCount ports closed, $errorCount other errors." -ForegroundColor Green

    # Show breakdown by port
    $portSummary = $SuccessfulResults | Group-Object Port | Sort-Object Name
    foreach ($portGroup in $portSummary) {
        $serviceType = if ($portGroup.Name -eq "636") { "LDAPS" } else { "HTTPS" }
        Write-Host "  Port $($portGroup.Name) ($serviceType): $($portGroup.Count) certificates" -ForegroundColor Cyan
    }

    # Show OS detection summary if enabled
    if ($GetOsType) {
        $osResults = $SuccessfulResults | Where-Object { $_.OSType -and $_.OSType -ne "Unknown" }
        if ($osResults.Count -gt 0) {
            Write-Host "OS Detection Summary:" -ForegroundColor Yellow
            $osSummary = $osResults | Group-Object OSType | Sort-Object Count -Descending
            foreach ($osGroup in $osSummary) {
                Write-Host "  $($osGroup.Name): $($osGroup.Count) hosts" -ForegroundColor Cyan
            }
        }
    }

    # Show thread usage summary
    $threadSummary = $Fullresult | Where-Object { $_.ThreadId } | Group-Object ThreadId | Measure-Object
    if ($threadSummary.Count -gt 0) {
        Write-Host "Utilized $($threadSummary.Count) threads for parallel processing" -ForegroundColor Yellow
    }

    if ($PSBoundParameters.Keys -like "SaveAsTo"){
        Save-Results -Results $Fullresult -SaveAsTo $SaveAsTo
    }
    if (($PSBoundParameters.Keys -like "*email*")){
        SendMailToTheInternet `
            -Fullresult $Fullresult `
            -EmailFrom $EmailFrom `
            -EmailSendTo $EmailSendTo `
            -EmailSubject $EmailSubject `
            -EmailSMTPServer $EmailSMTPServer `
            -EmailSMTPServerPort $EmailSMTPServerPort `
            -EmailSMTPServerSSL $EmailSMTPServerSSL
    }
    return $Fullresult
}

## Start for File Load and Scan
if ($PSCmdlet.ParameterSetName -eq "ReadFromFile") {
    if (!(Test-Path $LoadFromFile)){Throw "Incorrect Source Path."}
    $Fullresult=@()
    $CertificateList=Get-Content -Path $LoadFromFile
    Foreach($url in $CertificateList){
        $siteresults=ScanSiteInformaiton -URLScanSiteInfo $url -IncludeReverseDNS:$IncludeReverseDNS -GetOsType:$GetOsType -DnsServer $DnsServer
        $Fullresult+=$siteresults
    }
    
    # Apply expiration filter only if ExpiresInDays parameter was explicitly provided
    if ($PSBoundParameters.ContainsKey("ExpiresInDays") -or $ExcludeExpired) {
         $Fullresult = Apply-ExpirationFilter -Results $Fullresult -ExpiresInDays $ExpiresInDays -ExcludeExpired:$ExcludeExpired
    }

    if ($PSBoundParameters.Keys -like "SaveAsTo"){
        Save-Results -Results $Fullresult -SaveAsTo $SaveAsTo
    }
    if (($PSBoundParameters.Keys -like "*email*")){
        SendMailToTheInternet `
            -Fullresult $Fullresult `
            -EmailFrom $EmailFrom `
            -EmailSendTo $EmailSendTo `
            -EmailSubject $EmailSubject `
            -EmailSMTPServer $EmailSMTPServer `
            -EmailSMTPServerPort $EmailSMTPServerPort `
            -EmailSMTPServerSSL $EmailSMTPServerSSL
    }
    return $Fullresult
}

if ($pscmdlet.ParameterSetName -eq "Online") {
   $Fullresult=ScanSiteInformaiton -URLScanSiteInfo $SiteToScan -IncludeReverseDNS:$IncludeReverseDNS -GetOsType:$GetOsType -DnsServer $DnsServer
   
   # Apply expiration filter only if ExpiresInDays parameter was explicitly provided
   if ($PSBoundParameters.ContainsKey("ExpiresInDays") -or $ExcludeExpired) {
       $Fullresult = Apply-ExpirationFilter -Results $Fullresult -ExpiresInDays $ExpiresInDays -ExcludeExpired:$ExcludeExpired
   }

   if ($PSBoundParameters.Keys -like "SaveAsTo"){
        Save-Results -Results $Fullresult -SaveAsTo $SaveAsTo
    }
    if (($PSBoundParameters.Keys -like "*email*")){
        SendMailToTheInternet `
            -Fullresult $Fullresult `
            -EmailFrom $EmailFrom `
            -EmailSendTo $EmailSendTo `
            -EmailSubject $EmailSubject `
            -EmailSMTPServer $EmailSMTPServer `
            -EmailSMTPServerPort $EmailSMTPServerPort `
            -EmailSMTPServerSSL $EmailSMTPServerSSL
    }
   return $Fullresult
}
