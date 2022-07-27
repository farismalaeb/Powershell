# Send Users Password Notification to Teams and Email using Graph and PowerShell

The **PasswordExpire.ps1** is a PowerShell script to send a notification for the users reminding them with the password expiry.

This Scripte accept the following parameters:

- [Required][int] **NumberofDay**: Number of days left in the users password before sending the notification, a good starting point is 7
- [Not Required][String] **LDAPdistinguishedName**: The DN of the OU the users are located. as you might only use this scripe on a test range of users.

## Example:

.\PasswordExpire.ps1 -NumberofDay 1 -LDAPdistinguishedName 'OU=Employees,DC=Test,DC=com'

## Requirement

This script require the following graph permission 'Chat.Create','Chat.ReadWrite','Mail.Send','User.Read','User.Read.All'

## TeamsExamples.ps1

This file contain some example on how to use the Teams endpoint to do extra task, such as including pictures or additional mentions.
