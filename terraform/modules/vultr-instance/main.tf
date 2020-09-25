resource "vultr_server" "instance" {
    plan_id = var.plan_id
    region_id = var.region_id
    os_id = var.os_id
}