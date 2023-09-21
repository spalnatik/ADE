# ADE (Azure Disk Encryption)

The script performs the steps outlined in the provided documentation:

Enable Azure Disk Encryption for Linux VMs - Azure Virtual Machines | Microsoft Learn

https://learn.microsoft.com/en-us/azure/virtual-machines/linux/disk-encryption-overview

**Usage**:
 
**The script will do the following:**
 
-	It will prompt the user to provide a username and password, which will be used to access the ADE VM.
-	It will request the VM name and a unique keyvault name. Additionally it will verify if the provided Key Vault name is unique and not in a soft deleted state.
-	It will ask user to provide number of disks to add and type of format (Ex: ext4,xfs).
-	Create resource group, VNET, Key vault , key vault key, VM and data disks .
-	By default it uses RedHat7.9 (RedHat:RHEL:7_9:latest), you can use any other image by adding the option -i and image Urn.
  	Ex:
  	- ./ADE.sh -i RedHat:RHEL:7_9:latest
-	After attaching data disks “format.sh”  custom script will perform formatting disk and will create File systems.
-	If no data disks are declared, it will encrypt only the OS disk. If data disks are declared, it will encrypt both the OS and data disks.
-	Updating NSGs with public IP and allowing ssh access. 



**Tools required to run it:**

-	WSL (windows subsystem for Linux) or any Linux system.
-	Azure CLI installed on the machine and already logged in.
