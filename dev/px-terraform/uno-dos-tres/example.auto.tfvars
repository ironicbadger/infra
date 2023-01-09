proxmox_api_url = "https://123:8006/api2/json"
proxmox_api_token_id = "root@pam!full"
proxmox_api_token_secret = "123"

cluster_udt_name = "k3s-lab"

cluster_udt_masters = {
    "master1" = {
        "mac" = "32:ee:a4:94:9d:ad"
        "target" = "m1"
    }
    "master2" = {
        "mac" = "b6:16:fe:7d:19:af"
        "target" = "m1"
    }
    "master3" = {
        "mac" = "b6:59:d3:fa:aa:c0"
        "target" = "anton"
    }
}
cluster_udt_nodes = {
    "node1" = {
        "mac" = "5a:b9:00:2e:bb:c2"
        "target" = "m1"
    }
    "node2" = {
        "mac" = "46:04:13:26:34:bd"
        "target" = "anton"
    }
}