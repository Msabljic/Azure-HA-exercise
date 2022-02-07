terraform {
    required_providers {
      azurerm = {
          source = "hashicorp/azurerm"
          version = "=2.95.0"
      }
    }
}

provider "azurerm" {
    features {}
}

#Creating Baseline Resources
#Create RG
resource "azurerm_resource_group" "azrg" {
    name = "Assignment1"
    location = "Canada east"
}

#Create Vnet
resource "azurerm_virtual_network" "vnet" {
  name                = "Vnet1"
  resource_group_name = azurerm_resource_group.azrg.name
  location            = azurerm_resource_group.azrg.location
  address_space       = ["10.0.0.0/16"]
}

#Create Subnet1
resource "azurerm_subnet" "Sub1" {
    name = "Subnet-1"
    resource_group_name = azurerm_resource_group.azrg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.1.0/24"]
}

# create lb pip
resource "azurerm_public_ip" "pip" {
  name = "piplb"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location
  allocation_method = "Static"
}

#Load Balancing Infrastructure
#lb
resource "azurerm_lb" "lb" {
  name = "nlb"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location

  frontend_ip_configuration {
    name = "Frontdoorip"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}
#Health probe
resource "azurerm_lb_probe" "probe" {
  resource_group_name = azurerm_resource_group.azrg.name
  loadbalancer_id = azurerm_lb.lb.id
  name = "Health_probe"
  port = 80
}

#backend pool
resource "azurerm_lb_backend_address_pool" "adpool"{
  loadbalancer_id = azurerm_lb.lb.id
  name = "backendaddresspool"
}

#lbrules 
resource "azurerm_lb_rule" "lbru" {
  resource_group_name = azurerm_resource_group.azrg.name
  loadbalancer_id = azurerm_lb.lb.id
  name = "LBRule"
  protocol = "Tcp"
  frontend_port = 80
  backend_port = 80
  frontend_ip_configuration_name = "Frontdoorip"
  probe_id = azurerm_lb_probe.probe.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.adpool.id
}

#NSG and association
#NSG & rules for server
resource "azurerm_network_security_group" "nsg" {
  name = "networksecurity"
  location = azurerm_resource_group.azrg.location
  resource_group_name =azurerm_resource_group.azrg.name

  security_rule {
    name = "http"
    priority = 110
    direction = "Inbound"
    access = "Allow"
    protocol = "TCP"
    source_port_range = "*"
    destination_port_range = "80"
    source_address_prefix ="*"
    destination_address_prefix = "*"
    }
}

#Network Group association
resource "azurerm_subnet_network_security_group_association" "assocnsg"{
  subnet_id = azurerm_subnet.Sub1.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#Network interface
resource "azurerm_network_interface" "nic0" {
  name = "vmnic0"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location

    ip_configuration {
      name = "IPconfig"
      subnet_id =azurerm_subnet.Sub1.id
      private_ip_address_allocation ="Dynamic"
  }
}

#Network interface
resource "azurerm_network_interface" "nic1" {
  name = "vmnic1"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location

    ip_configuration {
      name = "IPconfig"
      subnet_id =azurerm_subnet.Sub1.id
      private_ip_address_allocation ="Dynamic"
  }
}
#Backend creation
#availability set
resource "azurerm_availability_set" "avset" {
  name = "avset"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
  managed = true
}

#VM1 create
resource "azurerm_windows_virtual_machine" "VM1" {
  name ="Server1"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location
  availability_set_id = azurerm_availability_set.avset.id
  size = "standard_F2"
  admin_username = "azureadmin"
  admin_password = "A1b2c3D4!"
  network_interface_ids = [azurerm_network_interface.nic1.id]
  os_disk {
    caching ="ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer ="WindowsServer"
    sku = "2016-Datacenter"
    version = "latest"
    }
}

#VM0 Create
resource "azurerm_windows_virtual_machine" "VM0" {
  name ="Server0"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location
  availability_set_id = azurerm_availability_set.avset.id
  size = "standard_F2"
  admin_username = "azureadmin"
  admin_password = "A1b2c3D4!"
  network_interface_ids = [azurerm_network_interface.nic0.id]
  os_disk {
    caching ="ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer ="WindowsServer"
    sku = "2016-Datacenter"
    version = "latest"
    }
}

#Backend0 assoc
resource "azurerm_network_interface_backend_address_pool_association" "backendassoc0" {
  network_interface_id = azurerm_network_interface.nic0.id
  ip_configuration_name   = "IPconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.adpool.id
}

#Backend1 assoc
resource "azurerm_network_interface_backend_address_pool_association" "backendassoc1" {
  network_interface_id = azurerm_network_interface.nic1.id
  ip_configuration_name   = "IPconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.adpool.id
}

#Bastion Infrastruture
#Create Subnet2
resource "azurerm_subnet" "Sub2" {
    name = "AzureBastionSubnet"
    resource_group_name = azurerm_resource_group.azrg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.2.0/24"]
}

#bastion host

#nic
resource "azurerm_network_interface" "nicbast" {
  name = "bastionnic"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location

    ip_configuration {
      name = "IPconfig2"
      subnet_id =azurerm_subnet.Sub1.id
      private_ip_address_allocation ="Dynamic"
  }
}

#VM create
resource "azurerm_windows_virtual_machine" "VMbast" {
  name ="Jumper"
  resource_group_name = azurerm_resource_group.azrg.name
  location = azurerm_resource_group.azrg.location
  size = "standard_F2"
  admin_username = "azureadmin"
  admin_password = "A1b2c3D4!"
  network_interface_ids = [azurerm_network_interface.nicbast.id]
  os_disk {
    caching ="ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer ="WindowsServer"
    sku = "2016-Datacenter"
    version = "latest"
    }
}
