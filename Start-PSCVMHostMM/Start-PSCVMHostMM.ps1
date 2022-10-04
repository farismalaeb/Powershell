<# .Description
    Function To Move VMs From one ESXi host to other 
    It Depend on the host Memory availibilty 
    .Example
    Start-PSCVMHostMM.ps1 -FromVMHostName MyVMHostServer -MaxMemAllowed 90 -FromCluster Production
    -FromVMHostName: The Source VMHost Server
    -MaxMemAllowed: Percentage of memory limit, default is 90, if the server memory load is 90% or more VMs wont be moved to this server
    -FromCluster: Cluster name where the hosts are exist
    This Script is for free you can update and use it as you want, Please add your name under the contributor
    Created By: 
     -Faris Malaeb
    

#>


param(
[parameter(mandatory=$True)]$FromVMHostName,
[parameter(mandatory=$False)]$MaxMemAllowed="90", #The utilized memory percentage threshold
[parameter(mandatory=$false)]$vCenter, #vCenter IP or name, This value will be ignored if you already connected
[parameter(mandatory=$True)]$FromCluster # The Source Cluster Name
)

if ((Get-Module -ListAvailable | where {$_.name -like 'VMware.VimAutomation.Core'})){Import-Module VMware.VimAutomation.Core -Prefix PSC}
Else{
Throw "VMware Module is not installed..."
}

$Finalresult=""

try{
     if (!($global:DefaultVIServer)){ #If No Connection to VC found then the script will start a new connection, otherwise the -vCenter Parameter is ignored
                write-host "Please Connect to vCenter using Connect-VIServer first" -ForegroundColor Yellow 
                $VC=Get-Credential -Message "Please type the username and password for vCenter" -ea Stop 
                Connect-PSCVIServer -Credential $VC -Server $vCenter
                
        }

    Write-Host "Performing Cluster Health For Load Sharing..." -ForegroundColor Green

    #To get a list of VMHosts in the cluster that VMs can move to, excpte the unhealth servers and the VM Hosting server that VMs will be migrated from

    Write-Host "Getting a list of VMs in host "$FromVMHostName -ForegroundColor Yellow
    #Get a list of VM on the server that should be migrated. only powered on VM.. I dont care about powered off VM
    
    $VMsInHost=Get-PSCVMHost $FromVMHostName | Get-PSCVM | where{$_.PowerState -like "*On"}

    Foreach($SingleVM in $VMsInHost){
    $AllhostInCluster=@()
    $WorkingNodes=Get-PSCCluster -Name $FromCluster -ea Stop | Get-PSCVMHost | where{($_.name -notlike $FromVMHostName) -and ($_.ConnectionState -notlike "*main*") -and ($_.ConnectionState -notlike "NotResponding")-and ($_.ConnectionState -notlike "Unknown")} |Sort-Object -Property MemoryUsageGB
    $AllhostInCluster+=$WorkingNodes
    Write-host "Parsing VM " $SingleVM.Name -ForegroundColor Green
        
        [int]$NewVMServerMemsize=$AllhostInCluster[0].MemoryUsageGB + $SingleVM.MemoryGB
          
        [int]$Percentage=$NewVMServerMemsize / (Get-PSCVMHost -Name $AllhostInCluster[0].Name -ErrorAction Stop).MemoryTotalGB *100 #To Get the Percentage
        Write-Host "The New Expected Memory Usage on"$AllhostInCluster[0].name "is:"$NewVMServerMemsize"," $Percentage"%" -ForegroundColor Green
            if ($Percentage -ge $MaxMemAllowed){
            Write-Host "I check the most free server and it cannot handle the load" -ForegroundColor red -BackgroundColor Yellow
            Write-Host "Percentage of free Memory on Server after Migration to =$($AllhostInCluster[0].name) $($Percentage)" -ForegroundColor red -BackgroundColor Yellow
            Write-host "I give up on this :(" -ForegroundColor red -BackgroundColor Yellow
            }
            If ($Percentage -lt $MaxMemAllowed){
                Try{
                    Write-Host "Moving $SingleVM.Name to" $AllhostInCluster[0].name -ForegroundColor Green
                    Move-PSCVM -VM $SingleVM.Name -Destination $AllhostInCluster[0].Name -ErrorAction Stop
                    $Finalresult=$Finalresult+$SingleVM.Name +" Success to "+ $AllhostInCluster[0].Name +"`n"
                    Write-Host $SingleVM.Name" is now located in "$AllhostInCluster[0].Name
                    
                    }
                    Catch{
                    Write-Host $_.Exception.message -ForegroundColor red
                    $Finalresult=$Finalresult+$SingleVM.Name +" FAILED to "+ $AllhostInCluster[0].Name +"`n"
                    
                 }
            }


        }


}


    Catch [exception]{
        Write-Host $_.Exception.message -ForegroundColor red
        Break
    }


Finally{
$Finalresult
if ((get-pscvm | where{($_.host -like $FromVMHostName) -and ($_.PowerState -like "*on")}).count -eq 0){Write-Host "I am done.. Go check the host "}
if ((get-pscvm | where{($_.host -like $FromVMHostName) -and ($_.PowerState -like "*on")}).count -gt 0){Write-Host "It seems that VM Migration not completed. maybe some resource issue"}

}