# Send-GraphMail

Send Microsoft Graph Email messaging using a simplified approach

## DESCRIPTION

    Send Microsoft Graph Email messaging using a simplified approach with support to a multiple parameters.

## PARAMETER

````Send-GraphMail```` Support the following parameters:

- [Array] **To**: The recipients address, it can be an array for multiple account, just make sure to include the array type @("User1@domain.com","User2@Domain.com").
- [Array] **Bcc**: Similar to To, but this is the BCC and also support array of recipients.
- [Array] **CC**: Similar to To and Bcc, also support array of recipients.
- [String] **Subject**: The Message Subject
- [String] **MessageFormat**: it can be HTML or Text
- [String] **Body**: The Message Body you want to send.
- [Switch] **BodyFromFile**: This is a Switch parameter. Using it mean that the body is stored in a file in your hard drive. When using the BodyFromFile, the Body parameter should be the full path of the file.
- [Switch] **DeliveryReport**: Set to receive a delivery report email or not
- [Switch] **ReadReport**: set to receive a read report or not.
- [Switch] **Flag**: enable the follow-up flag for the message
- [ValidationSet] **Importance**: Set the message priority, it can be one of the following, Low or High
- [String] **Attachments**: The Attachment file path. For now it only support 1 attachment, if you want more, let me know
- [String] **DocumentType**: The attachment MIME type, for example for text file, the DocumentType is text/plain
- [Switch] **ReturnJSON**: This wont send the email, but instead it return the JSON file fully structured and ready so you can invoke it with any other tool.
- [HashTable] **MultiAttachment**: Use this parameter to send more than one attachment, this parameter is a Hashtable as the following @{"Attachment Path No.1"="DocumentType";"Attachment Path No.2"="DocumentType"}. You cannot use the MultiAttachment with Attachments parameter

> Beta endpoints are not included, such as Mentions.

## EXAMPLE

Send Graph email message to multiple users with attachments and multiple To, CC and single Bcc

```Send-GraphMail -To @('user1@domain.com','user2@domain.com') -CC @('cc@domain.com','cc1@domain.com') -Bcc "bcc@domain.com" -Subject "Test Message" -MessageFormat HTML -Body 'This is the Message Body' -DeliveryReport -ReadReport -Flag -Importance High -Attachments C:\MyFile.txt -DocumentType 'text/plain'```

Send Graph email, load the Body from a file stored locally, make sure to use the BodyFromFile switch

````Send-GraphMail -To 'ToUser@powershellcenter.com' -Subject "Test Message" -MessageFormat HTML -Body C:\11111.csv -BodyFromFile -DeliveryReport -ReadReport -Flag -Importance High -Attachments 'C:\MyFile.txt' -DocumentType 'text/plain'````

Return and get how the JSON is structured without sending the Email, this is done by using the -ReturnJSON Parameter

````$JSONFile=send-GraphMail -To 'ToUser@powershellcenter.com' -Subject "Test Message" -MessageFormat HTML -Body "Hi This is New Message" -Flag -ReturnJSON````

Send Graph email including multiple attachment.

````Send-GraphMail -To "ToUser@powershellcenter.com" -CC "farisnt@gmail.com" -Bcc "CCUser@powershellcenter.com" -Subject "Test V1" -MessageFormat HTML -Body "Test" -MultiAttachment @{"C:\11111.csv"="text/plain";"C:\222222.csv"="text/plain"}````

## NOTES

This script will authenticate with the correct right scope.

## Full help

Read more about it [PowerShell Center](https://www.powershellcenter.com/2022/09/07/powershell-script-to-simplify-send-mgusermail/).
