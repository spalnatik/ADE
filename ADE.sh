#!/bin/bash

timestamp=$(date +"%Y-%m-%d %H:%M:%S")

echo "Script execution started at: $timestamp"

#set -x


rgname="dencryption-RG"
offer="RedHat:RHEL:7_9:latest"
KEYNAME="adekeyfmt"
STORAGEACCOUNTNAME="diskencryptadediag"
loc="SouthCentralUS"
sku_size="Standard_D2s_v3"
vnetname="dencryption-RG-vnet"
subnetname="ADE-subnet"
logfile="ADE.log"

# Parse command line arguments
while getopts "i:" opt; do
  case $opt in
    i) offer=$OPTARG ;;
    *) ;;
  esac
done

echo "Offer: $offer"

if [ -f "./username.txt" ]; then
    username=$(cat username.txt)
else
    read -p "Please enter the username: " username
fi

if [ -f "./password.txt" ]; then
    password=$(cat password.txt)
else
    read -s -p "Please enter the password: " password
fi

echo ''

read -p "Please enter the vmname: " vmname


function check_resource_group_exists {
    az group show --name "$1" &> /dev/null
}

if check_resource_group_exists "$rgname"; then
    	read -p "Enter the unique keyvault name: " KEYVAULTNAME
	echo "Resource group '$rgname' already exists. Skipping keyvault creation..."

else
# Function to check if the Key Vault name exists (including soft-deleted)
check_keyvault_exists() {
    local keyvault_name="$1"
    local existing_kv
    existing_kv=$(az keyvault list --query "[?name=='$keyvault_name'].name" --output tsv 2>/dev/null)
    soft_deleted_kv=$(az keyvault list-deleted --query "[?name=='$keyvault_name'].name" --output tsv 2>/dev/null)
    
    if [ -n "$existing_kv" ] || [ -n "$soft_deleted_kv" ]; then
        return 0 # Key Vault exists
    else
        return 1 # Key Vault does not exist
    fi
}

while true; do
    read -p "Enter the unique keyvault name: " KEYVAULTNAME
    
    if check_keyvault_exists "$KEYVAULTNAME"; then
        echo "Key Vault '$KEYVAULTNAME' already exists or was previously soft-deleted. Please choose a unique name."
    else
        # Break out of the loop only if the provided name is unique
        break
    fi
done
fi

echo ''
read -p "Enter the number of disks to attach: " num_disks

read -p "Enter FSType of disks: " ftype

echo ""
date >> "$logfile"

if check_resource_group_exists "$rgname"; then
    echo "Resource group '$rgname' already exists. Skipping RG creation..."
else
echo "Creating RG $rgname.."
az group create --name "$rgname" --location "$loc" >> "$logfile"

echo "Creating VNET .."
az network vnet create --name "$vnetname" -g "$rgname" --address-prefixes 10.0.0.0/24 --subnet-name "$subnetname" --subnet-prefixes 10.0.0.0/24 >> "$logfile"

echo "Creating key Vault .."
az keyvault create --name ${KEYVAULTNAME}  --resource-group ${rgname} --location ${loc} --enabled-for-disk-encryption True --enabled-for-deployment True --enabled-for-template-deployment True -o table

echo "Creating key .."
az keyvault key create --vault-name ${KEYVAULTNAME} --name ${KEYNAME} --protection software
fi

echo "Creating ADE VM"

az vm create -g "$rgname" -n "$vmname" --admin-username "$username" --admin-password "$password" --image "$offer" --vnet-name "$vnetname" --subnet "$subnetname" --public-ip-sku Standard --size "$sku_size" >> "$logfile"

if [ $num_disks -gt 0 ]; then
    for ((i=1; i<=num_disks; i++))
    do
        disk_name="$vmname$i"
        size_gb=4

        az vm disk attach \
            -g "$rgname" \
            --vm-name "$vmname" \
            --name "$disk_name" \
            --new \
            --size-gb "$size_gb"

        if [ $? -eq 0 ]; then
            echo "Disk $disk_name successfully attached."
        else
            echo "Failed to attach disk $disk_name."
        fi
    done
fi


if [ $num_disks -gt 0 ]; then
    echo "format the newly attached disks"
    az vm extension set \
    --resource-group $rgname \
    --vm-name $vmname \
    --name customScript \
    --publisher Microsoft.Azure.Extensions \
    --protected-settings "{\"fileUris\": [\"https://raw.githubusercontent.com/spalnatik/ADE/main/format.sh\"],\"commandToExecute\": \"./format.sh $ftype\"}" >> $logfile
fi

if [ $num_disks -gt 0 ]; then
    echo "encrypting both OS and data disks"
    az vm encryption enable --resource-group "$rgname" --name "$vmname" --disk-encryption-keyvault "$KEYVAULTNAME" --key-encryption-key "$KEYNAME" --volume-type "ALL" --encrypt-format-all
 else
    echo "encrypting only OS disk "
    az vm encryption enable --resource-group "$rgname" --name "$vmname" --disk-encryption-keyvault "$KEYVAULTNAME" --key-encryption-key "$KEYNAME" --volume-type "OS"
fi   

echo 'Updating NSGs with public IP and allowing ssh access from that IP'
my_pip=`curl ifconfig.io`
nsg_list=`az network nsg list -g $rgname  --query [].name -o tsv`
for i in $nsg_list
do
        az network nsg rule create -g $rgname --nsg-name $i -n buildInfraRule --priority 100 --source-address-prefixes $my_pip  --destination-port-ranges 22 --access Allow --protocol Tcp >> $logfile
done

az vm encryption show --name ${VMNAME} --resource-group ${RGNAME} --query "substatus"

end_time=$(date +"%Y-%m-%d %H:%M:%S")

echo "Script execution completed at: $end_time"
