**Exchange Server 2019/2016 Maintenance**

Please read the full post about this Powershell here

**Version 1.0.6**  added the **-IgnoreQueue** Parameter to prevent Queue Transfer, this will help when the server that should go to maintenance have a big queued messages, but its OK to keep them.
This option can help in cases where the exchange server is in a remote office and the replacement server is in another location.
https://www.powershellcenter.com/2020/12/26/powershell-module-for-placing-exchange-server-in-out-maintenance-mode/

