<#
        .SYNOPSIS
        No parameters needed. Just execute the script.

        .DESCRIPTION
        The script deploys a couple of VMs to Azure.

        History  
        v0.1: Under development
     
        .EXAMPLE
        Deploy-AzureLab
    
        .NOTES
        Author: Patrick Terlisten, patrick@blazilla.de, Twitter @PTerlisten
    
        This script is provided 'AS IS' with no warranty expressed or implied. Run at your own risk.

        Make sure that you have a valid Azure Subscription. You can connect to a valid Azure Subscription
        by using the cmdlets Get-AzurePublishSettingsFile and Import-AzurePublishSettingsFile. You can check
        the currently available Azure Subscriptions in your user profile with Get-AzureAccount and
        Get-AzureSubscription.

        Parts of the code are based on New-AzureVM example script, which can be found under
        https://msdn.microsoft.com/en-us/library/mt125899.aspx

        This work is licensed under a Creative Commons Attribution NonCommercial ShareAlike 4.0
        International License (https://creativecommons.org/licenses/by-nc-sa/4.0/).
    
        .LINK
        http://www.vcloudnine.de
#>

#Requires -Version 3.0
#Requires -Module Azure, AzureRM.Profile

## Check if a Azure Subscription is available

if ((Get-AzureSubscription) -ne $null) {

    Write-Host `n
    Write-Host -ForegroundColor Green 'I have found at least one Azure Subscripion.'
    Write-Host `n
}

else {

    Write-Host `n
    Write-Host -ForegroundColor Red 'Sorry, no Azure Subscription available. Script will end now.'
    Write-Host `n
    break

}

break

## Core Parameters for all entities

$Location = 'WestEurope'
$VMResourceGroupName = 'lab-vm-rg'
$NetworkResourceGroupName = 'lab-vnet-rg'
$Credential = Get-Credential

## VMs to create
## Please do not remove this array.
## $ListofVMs = 'DC01','DC02','CA01'

$ListofVMs = 'DC01'

## Create Resource Group for core networking

if ((Get-AzureRmResourceGroup).ResourceGroupname -eq $NetworkResourceGroupName) {
    Write-Host -ForegroundColor Red "Resource Group $NetworkResourceGroupName already exists. Skipping this step."
}

else {

    New-AzureRmResourceGroup -Name $NetworkResourceGroupName -Location $Location

    ## Create core networking vNets and subnets
    
    $SubnetName = 'Subnet_192_168_201_0'
    $VNetName = 'Lab-vNet-192_168_201_0'
    $VNetAddressPrefix = '192.168.201.0/24'
    $VNetSubnetAddressPrefix = $VNetAddressPrefix
    $SubnetName = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $VNetSubnetAddressPrefix
    New-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $NetworkResourceGroupName -Location $Location -AddressPrefix $VNetAddressPrefix -Subnet $SubnetName

}

## Create Resource Group for VMs

if ((Get-AzureRmResourceGroup).ResourceGroupname -eq $VMResourceGroupName) {
    Write-Output "Resource Group $VMResourceGroupName already exists. Skipping this step. "
}

else {
    New-AzureRmResourceGroup -Name $VMResourceGroupName -Location $Location
}


ForEach ($VM in $ListofVMs) {

    ## VM Config
    
    $VMName = $VM
    $ComputerName = $VMName
    $VMSize = 'Standard_A2_v2'
    $OSDiskName = $VMName + '-OSDisk'
    $StorageName =  ($VMname + (Get-Random -Minimum 1000 -Maximum 10000)).ToLower()
    $StorageType = 'Standard_LRS'
    $InterfaceName = $VMName + '-Nic1'
    $PublicIP = New-AzureRmPublicIpAddress -Name $InterfaceName -ResourceGroupName $NetworkResourceGroupName -Location $Location -AllocationMethod Dynamic
    $vNet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $NetworkResourceGroupName
    $Interface = New-AzureRmNetworkInterface -Name $InterfaceName -ResourceGroupName $NetworkResourceGroupName -Location $Location -SubnetId $VNet.Subnets[0].Id -PublicIpAddressId $PublicIP.Id

    ## Setup local VM object
    
    $StorageAccount = New-AzureRmStorageAccount -ResourceGroupName $VMResourceGroupName -Name $StorageName -Type $StorageType -Location $Location
    $VirtualMachine = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzureRmVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
    $VirtualMachine = Set-AzureRmVMSourceImage -VM $VirtualMachine -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version 'latest'
    $VirtualMachine = Add-AzureRmVMNetworkInterface -VM $VirtualMachine -Id $Interface.Id
    $OSDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + 'vhds/' + $OSDiskName + '.vhd'
    $VirtualMachine = Set-AzureRmVMOSDisk -VM $VirtualMachine -Name $OSDiskName -VhdUri $OSDiskUri -CreateOption FromImage

    ## Create the VM in Azure
    
    New-AzureRmVM -ResourceGroupName $VMResourceGroupName -Location $Location -VM $VirtualMachine
}