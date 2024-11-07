<#
This script is a basic script intended to move data from FSLogix to another.
The intend is for moving users data from one VDI environment to another.

Requirements:
- Run it anywhere it have access to Old FSLogix User container.
- The Script should run under any account that can access user profile in an Active XenDesktop session
   This is mean that the script will copy the data from the old FSLogix to the users active VDI session
- Citrix.XenDesktop.Admin PowerShell Module.
- Run this script as Administrator.

How to use:
Please read the Post in www.powershellcenter.com for more information

#Parameters:
PickUpFolder [ String ]: The location where the script will read the Move request. excpected value any share folder \\Sharefolder\... 
VHDorVHDX [ String - Validation Set]: the format of the Old FSLogix container, possible value "VHD" or "VHDX".
OldProfilePath [ String ]: the location of the old FSLogix containers. Expected value: \\FileServer\FSLogix Profile 
NewDeliveryCTRL [ String ]: The New XenDesktop environement delivery controller name. Expected value MyVDIEnv.domain.local
SMTPEnabled [ switch ]: If presented the script will send email notification to the helpdesk agent.
SMTPServer [ String ]: SMTP Server to relay the message to.




#>

#requires -modules Citrix.XenDesktop.Admin
#requires -RunAsAdministrator
#required -modules Hyper-V

[Cmdletbinding(DefaultParameterSetName='vdi')]
param(
[parameter(Mandatory=$true,ParameterSetName='vdi')]
[parameter(ParameterSetName='Email')]$PickUpFolder,

[parameter(Mandatory=$false,ParameterSetName='vdi')]
[ValidateSet("VHD", "VHDX")]
[parameter(ParameterSetName='Email')]$VHDorVHDX='VHDX',

[parameter(Mandatory=$true,ParameterSetName='vdi')]
[parameter(ParameterSetName='Email')]$OldProfilePath,

[parameter(Mandatory=$false,ParameterSetName='Email')][switch]$SMTPEnabled,
[parameter(Mandatory=$true,ParameterSetName='Email')]$SMTPServer,
[parameter(Mandatory=$false,ParameterSetName='Email')]$SMTPSender="vdimigration@domain.com",
[parameter(Mandatory=$true,ParameterSetName='vdi')]
[parameter(ParameterSetName='Email')]$NewDeliveryCTRL
)

Function Set-Loginfo {
param(
$txtmsg,
$UserLog,
$dirToWrite
)
Write-Host "$(Get-Date)-->: $txtmsg"
Add-Content -Path (Join-Path $dirToWrite -ChildPath $($UserLog+".log")) -Value "$(Get-Date)-->: $txtmsg"
}

try{
Import-Module Citrix.XenDesktop.Admin  -ErrorAction Stop
if (!(test-path -Path "C:\Disks")){New-Item -Path "C:\" -Name "disks" -ItemType Directory}
}
catch{
Write-Host $error[0]
}

Try{
While($true){
$ReadAllFiles=Get-ChildItem -Filter *.dat -Path $PickUpFolder    
    if (!($ReadAllFiles.count -eq 0)){    
    foreach($File in $ReadAllFiles){      
        $UserToMigrate=Get-Content $File.FullName -ErrorAction Stop
         $FolderToCopy=((($UserToMigrate[0]).Split("="))[1]).Split(",")
        $FilesToCopy=((($UserToMigrate[1]).Split("="))[1]).Split(",")
        $SupportAgent=((($UserToMigrate[2]).Split("="))[1]).Split(",")
        $User=($File.Name).Remove(($file.name.Length) -4)
        $GBS=@{
              AdminAddress=$NewDeliveryCTRL
              SessionUserName="$($env:USERDOMAIN)\$($User)"
              }

            if ((Get-BrokerMachine @GBS)){$NewVDIName=(Get-BrokerMachine @GBS).MachineName.Substring(($env:USERDOMAIN.Length)+1)}
              Else{
         Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg "No Active Session Found!"
         Rename-Item -Path $File.FullName -NewName "$($File.Name).Error.$(Get-Date -Format "ss-mm-hh")"
         if ($SMTPEnabled){Send-MailMessage -To $SupportAgent -From $SMTPSender -Body "No Active Session for $($User)"  -SmtpServer $SMTPServer -Subject "User Migration for $($file.Name)" }
         Start-Sleep 2
        break
            }
        if ($SMTPEnabled){Send-MailMessage -To $SupportAgent -From $SMTPSender -Body "Process Started for  $($User), Please wait while processing..."  -SmtpServer $SMTPServer -Subject "User Migration for $($file.Name)" }
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg $File 
        $UserSid = (Get-ADUser -Identity $User).sid.value
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg $UserSid
        $UserDisk=Get-ChildItem -Filter "*.$($VHDorVHDX)" -Path $OldProfilePath -Recurse -ErrorAction  Stop | Where-Object {((($_.Directory.name.Split("_"))[0]) -like $UserSid) -or ((($_.Directory.name.Split("_"))[1]) -like $UserSid)}
        try{
            Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg "Disk name is $($UserDisk)"
            Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg "Prepare to Mount the VHD/x"
            Mount-VHD -Path $UserDisk.FullName -ReadOnly -ErrorAction Stop
          }
        Catch{
         Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg $error[0]
         Rename-Item -Path $File.FullName -NewName $("$File.Error.$(Get-Date -Format "ss-mm-hh")")
        break
        }
        $DiskName=$UserDisk.Name.Replace("_","-").substring(0,($UserDisk.Name.Length -($VHDorVHDX.Length)-1))

        New-Item -Path C:\Disks -Name $DiskName -ItemType Directory
        Get-Volume | Where-Object{$_.FileSystemLabel -like $DiskName} | Get-Partition | Add-PartitionAccessPath -AccessPath C:\Disks\$DiskName
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  (Get-Volume -FileSystemLabel $DiskName)

        $DiskInfo=Get-Volume | Where-Object{$_.FileSystemLabel -like $DiskName} | Get-Partition | Select-Object Disknumber,PartitionNumber
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  "$($DiskName) DiskNumber is $($DiskInfo.Disknumber)"
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  "$($DiskName) PartitionNumber is $($DiskInfo.PartitionNumber)"

        if ($FolderToCopy){
        foreach($SingleFolder in  $FolderToCopy){
        Trap{
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  "Ops Error happense $($Error[0])"
        continue
        }
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  "Copying C:\Disks\$($DiskName)\Profile\$($SingleFolder) to \\$($NewVDIName)\c$\Users\$($User)\$($SingleFolder)"
        Copy-Item -Path "C:\Disks\$($DiskName)\Profile\$($SingleFolder)" -Destination "\\$($NewVDIName)\c$\Users\$($User)\$($SingleFolder)" -Recurse -ErrorAction Stop

        }
        }

        if ($FilesToCopy){
        foreach($SingleFile in  $FilesToCopy){
        Trap{
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  "Ops Error happense $($Error[0])"
        continue
        }
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg   "C:\Disks\$($DiskName)\Profile\$($SingleFile) to \\$($NewVDIName)\c$\Users\$($User)\$($SingleFile)"
        Copy-Item -Path "C:\Disks\$($DiskName)\Profile\$($SingleFile)" -Destination "\\$($NewVDIName)\c$\Users\$($User)\$($SingleFile)" -Recurse -ErrorAction Stop -Force

        }
        }

                Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  "Unmounting the point"
                $RPAP=@{
                AccessPath="C:\Disks\$($diskname)"
                DiskNumber=$DiskInfo.Disknumber
                PartitionNumber=$DiskInfo.PartitionNumber
                }
                Remove-PartitionAccessPath @RPAP
                Dismount-VHD -DiskNumber $DiskInfo.Disknumber
                $filenameToSend=$file.FullName.Replace(".dat",".log")
                Write-Host "Sending email"
                if ($SMTPEnabled){Send-MailMessage -To $SupportAgent -From $SMTPSender -Body "Results for user $($User), Please check the attachemnet"  -SmtpServer $SMTPServer -Subject "User Migration for $($file.Name)" -Attachments $filenameToSend}
                write-host "Email Sent."

                Start-Sleep -Seconds 2
                Remove-Item -Path "C:\disks\$($diskname)"
                remove-item -Path $File.FullName
                


      }
   }
}


}
        catch{
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg $Error[0]
        Set-Loginfo -UserLog $User -dirToWrite $PickUpFolder -txtmsg  (Get-Volume)
        write-host $Error[0] #.Exception
        $filenameToSend=$file.FullName.Replace(".dat",".log")
        if ($SMTPEnabled){Send-MailMessage -To $SupportAgent -From $SMTPSender -Body "Results for user $($User), Please check the attachemnet"  -SmtpServer $SMTPServer -Subject "User Migration for $($file.Name)" -Attachments $filenameToSend}
        Rename-Item -Path $File.FullName -NewName $("$File.Error")

        break
        }
