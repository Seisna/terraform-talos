
locals {
  web_prefix = "web"
  web_labels = "project.io/node-pool=web"
}

resource "scaleway_instance_placement_group" "web" {
  name        = "web"
  policy_type = "max_availability"
  policy_mode = "enforced"
}

resource "scaleway_instance_ip" "web_v6" {
  count = lookup(try(var.instances[var.regions[0]], {}), "web_count", 0)
  type  = "routed_ipv6"
}

# resource "scaleway_ipam_ip" "web_v4" {
#   count   = lookup(try(var.instances[var.regions[0]], {}), "web_count", 0)
#   address = cidrhost(local.main_subnet, 21 + count.index)
#   source {
#     private_network_id = scaleway_vpc_private_network.main.id
#   }
# }

resource "scaleway_instance_server" "web" {
  count              = lookup(try(var.instances[var.regions[0]], {}), "web_count", 0)
  name               = "${local.web_prefix}-${count.index + 1}"
  image              = data.scaleway_instance_image.talos[length(regexall("^COPARM1", lookup(try(var.instances[var.regions[0]], {}), "web_type", 0))) > 0 ? "arm64" : "amd64"].id
  type               = lookup(var.instances[var.regions[0]], "web_type", "DEV1-M")
  security_group_id  = scaleway_instance_security_group.web.id
  placement_group_id = scaleway_instance_placement_group.web.id
  tags               = concat(var.tags, ["web"])

  routed_ip_enabled = true
  ip_ids            = [scaleway_instance_ip.web_v6[count.index].id]

  private_network {
    pn_id = scaleway_vpc_private_network.main.id
  }

  root_volume {
    size_in_gb = 20
  }

  user_data = {
    cloud-init = templatefile("${path.module}/templates/worker.yaml.tpl",
      merge(local.kubernetes, try(var.instances["all"], {}), {
        ipv4_vip    = local.ipv4_vip
        nodeSubnets = [one(scaleway_vpc_private_network.main.ipv4_subnet).subnet, one(scaleway_vpc_private_network.main.ipv6_subnets).subnet]
        labels      = local.web_labels
      })
    )
  }

  lifecycle {
    ignore_changes = [
      image,
      type,
      user_data,
    ]
  }
}
