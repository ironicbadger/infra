output "control_plane_ips" {
  description = "IP addresses of the control plane nodes (if DHCP assigns them)"
  value       = {
    for name, vm in proxmox_virtual_machine.talos_control_plane : name => vm.ipv4_addresses
  }
}

output "worker_node_ips" {
  description = "IP addresses of the worker nodes (if DHCP assigns them)"
  value       = {
    for name, vm in proxmox_virtual_machine.talos_workers : name => vm.ipv4_addresses
  }
}