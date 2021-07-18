# Enable VMWare vCenter Maintenance Mode

This PowerShell Script evaluate the most free VMHost in the same cluster and move all VMs from
the node that will be placed in maintenance.

The Script will not overload any node as you can set a max memory load nodes should handle such as 95 percent.

## Available parameters ##

 __Start-PSCVMHostMM.ps1 -FromVMHostName MyVMHostServer -MaxMemAllowed 95 -FromCluster Production -vCenter MyvCenterServer__
 
    - FromVMHostName: The Source VMHost Server.
    - MaxMemAllowed: Percentage of memory limit, default is 90, if the server memory load is 90% or more VMs wont be moved to this server.
    - FromCluster: Cluster name where the hosts are exist.
    - vCenter: vCenter IP address or name.
    
https://www.powershellcenter.com/2020/08/14/vmware_esxi_standard_maintenance/
