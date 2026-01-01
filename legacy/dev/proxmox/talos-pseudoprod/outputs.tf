output "control_plane_ips" {
  description = "IP addresses of the control plane nodes (if DHCP assigns them)"
  value       = {
    for name, vm in proxmox_vm_qemu.talos_control_plane : name => vm.default_ipv4_address
  }
}

output "worker_node_ips" {
  description = "IP addresses of the worker nodes (if DHCP assigns them)"
  value       = {
    for name, vm in proxmox_vm_qemu.talos_workers : name => vm.default_ipv4_address
  }
}