proxmox_api_url = "https://10.42.37.10:8006/api2/json"
proxmox_api_token_id = "root@pam!root"
proxmox_api_token_secret = "bcc0518c-a67c-4efa-8c1e-d6e44653aad4"

lab_cluster_name = "k3s-lab"

lab_cluster_nodes = {
    "master1" = {
        "mac" = "32:ee:a4:94:9d:ad"
        "target" = "clarkson"
        "disk" = "15G"
        "storage" = "shared"
    }
    "master2" = {
        "mac" = "b6:16:fe:7d:19:af"
        "target" = "hammond"
        "disk" = "15G"
        "storage" = "shared"
    }
    "master3" = {
        "mac" = "b6:59:d3:fa:aa:c0"
        "target" = "may"
        "disk" = "15G"
        "storage" = "shared"
    }
    "node1" = {
        "mac" = "5a:b9:00:2e:bb:c2"
        "target" = "clarkson"
        "disk" = "25G"
        "storage" = "shared"
    }
    "node2" = {
        "mac" = "46:04:13:26:34:bd"
        "target" = "hammond"
        "disk" = "25G"
        "storage" = "shared"
    }
    "node3" = {
        "mac" = "46:04:13:26:34:4f"
        "target" = "may"
        "disk" = "25G"
        "storage" = "shared"
    }
}