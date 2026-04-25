# c137 Host Tuning

Host-specific runtime fixes for `c137`.

## NVMe PCIe Power Management

The Samsung 970 PRO in `CPU SLOT4 PCI-E 5.0 X8` previously failed to wake from
`D3cold` after boot:

```text
Unable to change power state from D3cold to D0, device inaccessible
Try "nvme_core.default_ps_max_latency_us=0 pcie_aspm=off pcie_port_pm=off"
```

`c137` already had `pcie_aspm=off`. This role persists the missing kernel args:

- `nvme_core.default_ps_max_latency_us=0`
- `pcie_port_pm=off`

The role updates `/etc/kernel/cmdline` and refreshes Proxmox EFI boot entries
with `proxmox-boot-tool refresh`.

## Other Boot Cleanup

- Comments stale `nvidia-drm` and `nvidia-uvm` module autoload entries because
  the A4000 is passed through with `vfio-pci`.
- Disables `nvidia-persistenced` on the host for the same reason.
- Installs the current `c137` fancontrol hwmon mapping.
- Keeps the custom LXC GPU AppArmor profile syntactically valid so AppArmor can
  load all LXC profiles.
