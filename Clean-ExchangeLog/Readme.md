## Clean Exchange Service Logs

This script will clean and remove old Exchange Services Logs _Not Database Logs_ .

The Script support the following parameters

- **JustCalculate**: Get a summary of the total storage consumed by services logs (Exchange and IIS). _[Switch]_
- **SimulateDeleteLogs**: Simulate Deletion, which writes a log that lists all files subject to removal. _[Switch]_
- **LogsOlderXDays**: Only cleanup logs that are older than X number of days. _[Int]_
- **DeleteLogs**: Delete the old logs and free disk space. _[Switch]_
- **ExtraFolderToAdd** : Include additional folders, such as Temp or any other folders for cleaning during the cleanup process (.Logs and .ETL files only). _[Array]_

Read more here
https://www.powershellcenter.com/2021/03/06/exchange-log-routation