variable master_hostnames { type="list" }
variable master_public_ip { type="list" }
variable edge_hostnames { type="list" }
variable edge_public_ip { type="list" }
variable master_as_edge {}
variable edge_count {}
variable node_count {}
variable use_cloudflare {}
variable cluster_prefix {}
variable cloudflare_domain {}

# Generate Ansible inventory (identical for each cloud provider)
resource "null_resource" "generate-inventory" {

  # Trigger rewrite of inventory, uuid() generates a random string everytime it is called
  triggers {
    uuid = "${uuid()}"
  }

  # Write master
  provisioner "local-exec" {
    command =  "echo \"[master]\" > inventory"
  }
  # output the lists formated
  provisioner "local-exec" {
    command =  "echo \"${join("\n",formatlist("%s ansible_ssh_host=%s ansible_ssh_user=ubuntu", var.master_hostnames, var.master_public_ip))}\" >> inventory"
  }

  # Write edges
  provisioner "local-exec" {
    command =  "echo \"[edge]\" >> inventory"
  }
  # output the lists formated
  provisioner "local-exec" {
    command =  "echo \"${join("\n",formatlist("%s ansible_ssh_host=%s ansible_ssh_user=ubuntu", var.edge_hostnames, var.edge_public_ip))}\" >> inventory"
  }
  # only output if master is edge
  provisioner "local-exec" {
    command =  "echo \"${var.master_as_edge != true ? "" : join("\n",formatlist("%s ansible_ssh_host=%s ansible_ssh_user=ubuntu", var.master_hostnames, var.master_public_ip))}\" >> inventory"
  }

  # Write other variables
  provisioner "local-exec" {
    command =  "echo \"[master:vars]\" >> inventory"
  }
  provisioner "local-exec" {
    command =  "echo \"nodes_count=${1 + var.edge_count + var.node_count} \" >> inventory"
  }
  provisioner "local-exec" {
    command =  "echo \"node_count=${var.node_count}\" >> inventory"
  }
  # If cloudflare domain is set, output that domain, otherwise output a nip.io domain (with the first edge ip)
  provisioner "local-exec" {
    command =  "echo \"domain=${ var.use_cloudflare == true ? format("%s.%s", var.cluster_prefix, var.cloudflare_domain) : format("%s.nip.io", element(concat(var.edge_public_ip, var.master_public_ip), 0))}\" >> inventory"
  }
}
