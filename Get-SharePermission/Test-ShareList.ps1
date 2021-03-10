<#
    .SYNOPSIS
       Script to get a list of all share in all the servers.

    .DESCRIPTION
        Faris Malaeb.
       Read the full details here
       https://www.powershellcenter.com/2020/11/08/powershell-get-all-share-folders-and-perform-permission-test-read-write-delete-on-them-to-see-what-limited-user-can-do/

    .PARAMETER FirstParameter
        ImpersonateToWrite
        execute the Access,Read,Write,Delete action using this account, You will need to type the username and password 
        Expected input $True , $False

    .PARAMETER SecondParameter
        PathToWrite
        The path to where to write the .CSV file to
        Expected Input a Full Path with a file name ending with .CSV

    .INPUTS
        This script wont work with any pipline, if there is a need, please update it or let me know :)

    .OUTPUTS
        CSV and console result.

    .EXAMPLE
       .\Get-AllShare.ps1 -ImpersonateToWrite $true -PathToWrite C:\myresult.csv #for a full result and full test
       .\Get-AllShare.ps1 -ImpersonateToWrite $false -PathToWrite C:\myresult.csv    # For getting only the share without the  (AWRD test) and  
      

    .LINK
        www.powershellcenter.com
        farisnt@gmail.com
#>





Param(
[parameter(mandatory=$False)][Bool]$ImpersonateToWrite=$true,
[parameter(mandatory=$True)]$PathToWrite
)

$Alpha=@("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")

   if ($ImpersonateToWrite){
        $Cerd=Get-Credential -Message "Add the Credential to write with, make sure you are writing it correct, I dont want to do the work twice "
            if ($Cerd){Write-Host "OK, Will use "$Cerd.username ", This test might slow down the scanning progress, So please wait "
                $AvailableDrives=$Alpha | where {(Get-PSDrive).Name -notcontains $_} # Get All Available Drive letter for the PSDrive FileSystem Type
                 Write-Host "I will use drive letter" $AvailableDrives[-1] -ForegroundColor Yellow
                     
                }
            Else{$ImpersonateToWrite=$False
            }
        
        
    }

$AllDomainComputer=Get-ADComputer -Properties operatingsystem -Filter {(operatingsystem -like "*server*")}  # select -First 20
$Sharelist=@()
$singleshare=""
$singlecomputerName=""


    foreach ($singlecomputer in $AllDomainComputer){
        $singlecomputerName=$singlecomputer.name
   

        try{
            Write-Host "testing the connectivity with " $singlecomputerName -ForegroundColor Yellow
            Test-Connection -ComputerName $singlecomputername -Count 1 -ErrorAction Stop |Out-Null # Testing Network connectivity and hide all the display
            Write-Host "Host" $singlecomputername "is alive, I will get the share list excluding the admin shares" -ForegroundColor Yellow
                 $allshares=Get-WmiObject -Class win32_share -ComputerName $singlecomputername | where {$_.path -like "*:\*"} #listing all the share including the admin Share, But Excluding the Printers 
                    foreach($singleshareName in $allshares){
                            $singleshare=$singleshareName.Name
                            $singlecomputerName=$singlecomputer.name
                            ############################################ Cluster Resouce Found 
                            if ($singleshareName.Name -like "\\*"){  
                            
                                Write-Host "AAAH, I found Cluster resource"
                                $singleshare=$singleshareName.Name.Split("\")[3]
                                $singlecomputerName=$singleshareName.Name.Split("\")[2]
                                }
                           ############################################# End Cluster Resource Discovery
                  
                        $ShareParam=New-Object PSobject
                        $ShareParam | Add-Member -NotePropertyName "ShareName" -NotePropertyValue $null 
                        $ShareParam | Add-Member -NotePropertyName "ServerName" -NotePropertyValue $null
                            if ($ImpersonateToWrite){
                                    $ShareParam | Add-Member -NotePropertyName "CanAccess" -NotePropertyValue $null
                                    $ShareParam | Add-Member -NotePropertyName "CanWrite" -NotePropertyValue $null
                                    $ShareParam | Add-Member -NotePropertyName "CanRead" -NotePropertyValue $null
                                    $ShareParam | Add-Member -NotePropertyName "CanDelete" -NotePropertyValue $null
                        
                            }

                        $ShareParam | Add-Member -NotePropertyName "IsAlive" -NotePropertyValue $null


                        if  (($singleshare -like "IPC$") -or ` ## This is an Admin share and I want to exclude it from my result
                            ($singleshare -like "Admin$") -or` #this is also an Admin Share
                            (($singleshare.Length -eq 2) -and (($singleshare.Substring(1)` -like "$"))))` #This will exclude all the Drive Share such as D$ or C$
                            {}
                        Else{
                        Write-Host "I found this share " -NoNewline            # just an informative message
                        Write-Host $singleshare -ForegroundColor Green -NoNewline    # just an informative message
                        Write-Host " on the following server" -NoNewline     # just an informative message
                        Write-Host $singlecomputerName -ForegroundColor Green      # just an informative message
                        $ShareParam.ShareName=$singleshare   #Assigning the Value to the Object
                        $ShareParam.ServerName=$singlecomputerName    #Assigning the Value to the Object
                        $ShareParam.IsAlive="Yes"
        
                                If($ImpersonateToWrite){
                                Write-Host "Read/Write/Delete Test is enabled..."
                                $FullPath="\\"+$singlecomputerName+"\"+$singleshare
                                $StopAllTests=$False
                                       ### Access Test
                                        Try{
                                            Write-Host "Trying to Access" ($AvailableDrives[-1]) "Via "$FullPath -ForegroundColor Yellow
                                            New-PSDrive -Name $AvailableDrives[-1] -PSProvider FileSystem -Root $FullPath -Credential $Cerd -ErrorAction Stop
                                            $ShareParam.CanAccess="Yes"

                                           }
                                        Catch{
                                            Write-Host $Cerd.UserName " Cannot access " $singleshare -ForegroundColor Yellow -NoNewline
                                            Write-Host $Error[-1].FullyQualifiedErrorId -ForegroundColor Red
                                            $ShareParam.CanAccess="No"

                                            $StopAllTests=$true #Assuming if the user cannot access to this folder, so the user wont be able to write or do anything else.
                                        }
                                        
                                        ### Write Test
                                        Try{
                                            if ($StopAllTests -like $False){
                                            Write-Host "Adding Content" ($AvailableDrives[-1]+":\PSCTestPSWrite.txt") -ForegroundColor Yellow -ErrorAction Stop
                                            "Test PowerShell Write for PSC Script" | Out-File ($AvailableDrives[-1]+":\PSCTestPSWrite.txt") -Force
                                            $ShareParam.CanWrite="Yes"}
                                            Else{
                                            $ShareParam.CanWrite="Cancelled"
                                                }

                                           }

                                        Catch{
                                            Write-Host $Cerd.UserName " Cannot Write " $singleshare -ForegroundColor Yellow
                                            Write-Host $_.Exception.Message
                                            $ShareParam.CanWrite="No"
                                            $ShareParam.CanDelete="No"
                                            $ShareParam.CanRead="Cancelled"
                                            $StopAllTests=$True #If no file written then there is no need to continue with the deletion
                                            
                                        }


                                        #### Can Read

                                         Try{
                                            if ($StopAllTests -like $False){
                                            Write-Host "Reading Content" ($AvailableDrives[-1]+":\PSCTestPSWrite.txt") -ForegroundColor Yellow -ErrorAction Stop 
                                            Get-Content ($AvailableDrives[-1]+":\PSCTestPSWrite.txt")
                                            $ShareParam.CanRead="Yes"}
                                           

                                           }

                                        Catch{
                                            Write-Host $Cerd.UserName " Cannot Write " $singleshare -ForegroundColor Yellow
                                            Write-Host $_.Exception.Message
                                            $ShareParam.CanRead="No"
                                            
                                            
                                        }
                                    ############ Can Delete File
                                        Try{
                                            if ($StopAllTests -like $False){
                                            Write-Host "Removing" ($AvailableDrives[-1]+":\PSCTestPSWrite.txt") -ForegroundColor Yellow 
                                            Remove-Item -Path ($AvailableDrives[-1]+":\PSCTestPSWrite.txt") -Force -Confirm:$False -ErrorAction Stop
                                            $ShareParam.CanDelete="Yes"}
                                            Else{
                                            $ShareParam.CanDelete="Cancelled"
                                                }

                                           }
                                        Catch{
                                            Write-Host $Cerd.UserName " Cannot Write " $singleshare -ForegroundColor DarkYellow
                                            $ShareParam.CanDelete="No"
                                            
                                        }


                                        #Start-Sleep -Seconds 10000
                                   Remove-PSDrive $AvailableDrives[-1]

                                }

                        $Sharelist+=$ShareParam  #Adding the result to the list 
                        #Write-Host $Sharelist

                             }
                         }


             }
        catch {
                Write-Host $singlecomputername "seems to be offline " -ForegroundColor Red -NoNewline 
                Write-Host  $_.Exception -ForegroundColor Red
                $ShareParam.ShareName="X-("   #Assigning the Value to the Object
                $ShareParam.ServerName=$singlecomputer.Name    #Assigning the Value to the Object
                $ShareParam.IsAlive="Dead"
                $Sharelist+=$ShareParam
          

              }


    }

    $Sharelist | Export-Csv -Path $PathToWrite -NoTypeInformation -Force 
    $Sharelist | ft