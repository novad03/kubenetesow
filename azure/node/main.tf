# Core settings
variable count {}

variable name_prefix {}
variable resource_group_name {}
variable location {}
variable vm_size {}
variable image_id {}

# SSH settings
variable ssh_user {}

variable ssh_key {}

# Network settings
variable subnet_id {}

variable security_group_id {}

variable assign_floating_ip {
  default = "false"
}

# Disk settings

# Storage type redundancy https://docs.microsoft.com/en-us/azure/storage/common/storage-redundancy
variable "disk_storage_account_type" {
  default = "Standard_LRS"
}

# Bootstrap settings
variable bootstrap_file {}

variable kubeadm_token {}

variable node_labels {
  type = "list"
}

variable node_taints {
  type = "list"
}

variable master_ip {
  default = ""
}

# Bootstrap
data "template_file" "instance_bootstrap" {
  template = "${file("${path.root}/../${ var.bootstrap_file }")}"

  vars {
    kubeadm_token = "${var.kubeadm_token}"
    master_ip     = "${var.master_ip}"
    node_labels   = "${join(",", var.node_labels)}"
    node_taints   = "${join(",", var.node_taints)}"
    ssh_user      = "${var.ssh_user}"
  }
}

# Create public ip (optional)
resource "azurerm_public_ip" "pip" {
  count                        = "${var.assign_floating_ip ? var.count : 0}"
  name                         = "${var.name_prefix}-pip-${format("%03d", count.index)}"
  location                     = "${var.location}"
  resource_group_name          = "${var.resource_group_name}"
  public_ip_address_allocation = "static"
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  count                     = "${var.count}"
  name                      = "${var.name_prefix}-nic-${format("%03d", count.index)}"
  location                  = "${var.location}"
  resource_group_name       = "${var.resource_group_name}"
  network_security_group_id = "${var.security_group_id}"

  ip_configuration {
    name                          = "${var.name_prefix}-ipconfig"
    subnet_id                     = "${var.subnet_id}"
    private_ip_address_allocation = "Dynamic"

    # concat one empty object at en of list is workaround for terraform issue: https://github.com/hashicorp/terraform/issues/11210
    public_ip_address_id = "${var.assign_floating_ip ? element(concat(azurerm_public_ip.pip.*.id, list("")), count.index) : ""}"
  }
}

# Instance
resource "azurerm_virtual_machine" "vm" {
  count                 = "${var.count}"
  name                  = "${var.name_prefix}-${format("%03d", count.index)}"
  location              = "${var.location}"
  resource_group_name   = "${var.resource_group_name}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]

  storage_image_reference {
    id = "${var.image_id}"
  }

  storage_os_disk {
    name              = "${var.name_prefix}-${format("%03d", count.index)}-osdisk"
    managed_disk_type = "${var.disk_storage_account_type}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
  }

  os_profile {
    computer_name  = "${var.name_prefix}-${format("%03d", count.index)}"
    admin_username = "${var.ssh_user}"
    custom_data    = "${data.template_file.instance_bootstrap.rendered}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.ssh_user}/.ssh/authorized_keys"
      key_data = "${file(var.ssh_key)}"
    }
  }
}

# Generates a list of hostnames (azurerm_virtual_machine does not output them)
data "null_data_source" "hostnames" {
  count = "${var.count}"

  inputs = {
    hostname = "${var.name_prefix}-${format("%03d", count.index)}"
  }
}

# Module outputs
output "extra_disk_device" {
  value = ["/dev/sdc"]
}

output "local_ip_v4" {
  value = ["${azurerm_network_interface.nic.*.private_ip_address}"]
}

output "public_ip" {
  value = ["${azurerm_public_ip.pip.*.ip_address}"]
}

output "hostnames" {
  value = "${data.null_data_source.hostnames.*.inputs.hostname}"
}

output "node_labels" {
  value = "${var.node_labels}"
}
