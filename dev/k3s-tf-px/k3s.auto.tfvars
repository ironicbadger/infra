proxmox_api_url = "https://10.42.37.10:8006/api2/json"
proxmox_api_token_id = "root@pam!root"
proxmox_api_token_secret = "bc582d61-cf2e-4c84-a8e7-5680e03952fe"

cluster_name = "k3s-lab"
cluster_nodes = {
    "master1" = {
        "target" = "clarkson"
        "disk" = "25G"
        "storage" = "shared"
    }
    # "master2" = {
    #     "target" = "hammond"
    #     "disk" = "25G"
    #     "storage" = "shared"
    # }
    # "master3" = {
    #     "target" = "may"
    #     "disk" = "25G"
    #     "storage" = "shared"
    # }
    # "node1" = {
    #     "target" = "clarkson"
    #     "disk" = "50G"
    #     "storage" = "shared"
    # }
    # "node2" = {
    #     "target" = "hammond"
    #     "disk" = "50G"
    #     "storage" = "shared"
    # }
    # "node3" = {
    #     "target" = "may"
    #     "disk" = "50G"
    #     "storage" = "shared"
    # }
}