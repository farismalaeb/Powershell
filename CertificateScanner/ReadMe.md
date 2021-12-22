# Certificate Scanner

This script scans a list of defined domain for their SSL certificate.

This script scans for the following certificate details:

- Issued date
- Expiry date
- Issuer
- Subject name

## Using the CertificateScanner

The following parameters are available:

- **FilePath**: Path for a txt file that include the domains
- **ProtocolVersion**: Select the protocol to connect this include TLS, TLS1.1, TLS1.2 and SSLv3
- **SaveAsTo**: Location to save the result to (CSV).
- **EmailSendTo**: Send a copy of the report.
- **EmailFrom**: The Email Sender
- **EmailSMTPServer**: SMTP Server to use for mail relay.
- **EmailSMTPServerPort** SMTP Server Port, usually its 25
- **EmailSMTPServerSSL**: Use SSL for communication
- **EmailSubject**: The Message Subject to use.

> The **FilePath** should contain a site list one on each line, the format should be only the site without the https.
The script can sanitize the list and clear the list.

## Example

The following example scans a list of sites and show the result on the screen.

````powershell-console
.\CertificateScanner.ps1 -FilePath C:\test.txt

www.sdfkjsfds.ce  -- ERROR -->  Exception calling ".ctor" with "2" argument(s): "No such host is known."
The Full result are as the following

URL       : www.cnn.com
StartDate : 20-Apr-21 11:10:07 PM
EndDate   : 22-May-22 11:10:06 PM
Issuer    : CN=GlobalSign Atlas R3 DV TLS CA 2020, O=GlobalSign nv-sa, C=BE
Subject   : CN=*.api.cnn.com
Protocol  : Tls11

URL       : www.microsoft.com
StartDate : 29-Jul-21 1:22:06 AM
EndDate   : 29-Jul-22 1:22:06 AM
Issuer    : CN=Microsoft RSA TLS CA 01, O=Microsoft Corporation, C=US
Subject   : CN=www.microsoft.com, OU=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=WA, C=US
Protocol  : Tls11

URL       : www.google.com
StartDate : 29-Nov-21 7:36:34 AM
EndDate   : 21-Feb-22 7:36:33 AM
Issuer    : CN=GTS CA 1C3, O=Google Trust Services LLC, C=US
Subject   : CN=www.google.com
Protocol  : Tls11

URL       : www.sdfkjsfds.ce
StartDate : Exception calling ".ctor" with "2" argument(s): "No such host is known."
EndDate   : Exception calling ".ctor" with "2" argument(s): "No such host is known."
Issuer    :
Subject   :
````

## Saving the resulto to a file

You can use the certificate scanner to save the result to a file .csv by using the following command.

````powershell
.\CertificateScanner.ps1 -FilePath C:\Users\test.txt -NoCertValidation $true -SaveAsTo C:\MyResult.csv
````

## Sending the result by Email

````Powershell
.\CertificateScanner.ps1 -FilePath C:\Users\f.malaeb\test.txt -NoCertValidation $true -SaveAsTo C:\MyResult.csv -EmailSendTo Recp@domain.com -EmailFrom Sender@domain.com -EmailSMTPServer smtpserver.domain.com -EmailSMTPServerPort 25 -EmailSMTPServerSSL $false -EmailSubject "Scanning Result"
````

## Selecting the protocol

You can select the protocol to use during the connection. The available protocols are TLS, TLS1.1, TLS1.2, and SSLv3.

In the example below, the script uses SSLv3 to connect and get the certificate information.

````powershell
.\CertificateScanner.ps1 -FilePath C:\Users\f.malaeb\test.txt -NoCertValidation $true -SaveAsTo C:\MyResult.csv -ProtocolVersion Ssl3
````

> This depends on the client, the OS, and some security devices on the network route, as I did some tests, and sometimes the connection still uses the TLS1.2 even though the protocol argument is set to TLS1.0. If I was wrong, feel free and correct this point.

> Keep in mind that PowerShell 7 dont support SSLv3