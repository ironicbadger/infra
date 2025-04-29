locals {
  # Base node configurations
  control_plane_base = {
    memory    = 4096
    cores     = 4
    disk_size = "30G"
  }
  
  worker_base = {
    memory    = 8192
    cores     = 8
    disk_size = "250G"
  }

  # Node definitions
  nodes = {
    # Control plane nodes
    "talos-ctl1" = merge(local.control_plane_base, {
      id        = 5001
      mac       = "bc:24:11:b6:bd:66"
      role      = "control_plane"
    })
    "talos-ctl2" = merge(local.control_plane_base, {
      id        = 5002
      mac       = "bc:24:11:3a:b7:75"
      role      = "control_plane"
    })
    "talos-ctl3" = merge(local.control_plane_base, {
      id        = 5003
      mac       = "bc:24:11:f7:79:4a"
      role      = "control_plane"
    })

    # Worker nodes
    "talos-wrk1" = merge(local.worker_base, {
      id        = 5101
      mac       = "bc:24:11:35:73:ad"
      role      = "worker"
    })
    "talos-wrk2" = merge(local.worker_base, {
      id        = 5102
      mac       = "bc:24:11:2a:c4:6f"
      role      = "worker"
    })
    "talos-wrk3" = merge(local.worker_base, {
      id        = 5103
      mac       = "bc:24:11:ce:86:16"
      role      = "worker"
    })
  }

  # Filter nodes by role
  control_plane_nodes = {
    for name, node in local.nodes : name => node if node.role == "control_plane"
  }
  
  worker_nodes = {
    for name, node in local.nodes : name => node if node.role == "worker"
  }
}