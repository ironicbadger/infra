proxmox_api_url = "https://px.m.wd.ktz.me:8006/api2/json"
proxmox_api_token_id = "root@pam!full"
proxmox_api_token_secret = "1234"

cluster_udt_name = "k3s-lab"

cluster_udt = {
    "master1" = {
        "mac" = "32:ee:a4:94:9d:ad"
        "target" = "m1"
        "disk" = "15G"
        "storage" = "local"
    }
    "master2" = {
        "mac" = "b6:16:fe:7d:19:af"
        "target" = "m1"
        "disk" = "15G"
        "storage" = "local"
    }
    "master3" = {
        "mac" = "b6:59:d3:fa:aa:c0"
        "target" = "anton"
        "disk" = "15G"
        "storage" = "local"
    }
    "node1" = {
        "mac" = "5a:b9:00:2e:bb:c2"
        "target" = "m1"
        "disk" = "25G"
        "storage" = "local"
    }
    "node2" = {
        "mac" = "46:04:13:26:34:bd"
        "target" = "anton"
        "disk" = "25G"
        "storage" = "local"
    }
}