# Certificate Scanner

Please read the following post for a full explanation.

https://www.powershellcenter.com/2021/12/23/sslexpirationcheck/

This script scans for the following certificate details:

- URL
- Subject CN
- Issuer
- Issued Date
- Expire Date
- Protocol

## Using the CertificateScanner

The following parameters are available:

- [Mandatory, String]**LoadFromFile**: Path for a txt file that include the domains
- [Mandatory, String]**SiteToScan**: the site name you want to scan
- [Optional, ValidationSet]**ProtocolVersion**: Select the protocol to connect this include TLS, TLS1.1, TLS1.2 and SSLv3
- [Optional, String]**SaveAsTo**: Location to save the result to (CSV).
- [Optional, String]**EmailSendTo**: Send a copy of the report.
- [Optional, String]**EmailFrom**: The Email Sender
- [Optional, String]**EmailSMTPServer**: SMTP Server to use for mail relay.
- [Optional, String]**EmailSMTPServerPort**: SMTP Server Port, usually its 25
- [Optional, Switch]**EmailSMTPServerSSL**: Use SSL for communication
- [Optional, String]**EmailSubject**: The Message Subject to use.

> The LoadFromFile should contain a site list one on each line, the format should be only the site without the https. The script can sanitize the list and clean the list, so if your domain list include the protocol, its OK. Also you can include sites with a custome secure port for example www.google.com:8443.


## Example

The following example scans a list of sites and show the result on the screen.

````powershell-console
PS7 > .\CertificateScanner.ps1 -LoadFromFile C:\Users\sitelist.txt

The Full result are as the following

URL       : www.cnn.com
StartDate : 20-Apr-21 11:10:07 PM
EndDate   : 22-May-22 11:10:06 PM
Issuer    : CN=GlobalSign Atlas R3 DV TLS CA 2020, O=GlobalSign nv-sa, C=BE
Subject   : CN=*.api.cnn.com
Protocol  : Default

URL       : 192.168.10.10
StartDate : 07-Mar-16 12:27:35 PM
EndDate   : 02-Mar-26 12:27:34 PM
Issuer    : O=VMESXI.server.com, C=US, DC=local, DC=vsphere, CN=CA
Subject   : C=US, CN=VMESXI.server.com
Protocol  : Default

URL       : www.google.com
StartDate : 29-Nov-21 7:36:34 AM
EndDate   : 21-Feb-22 7:36:33 AM
Issuer    : CN=GTS CA 1C3, O=Google Trust Services LLC, C=US
Subject   : CN=www.google.com
Protocol  : Default
````