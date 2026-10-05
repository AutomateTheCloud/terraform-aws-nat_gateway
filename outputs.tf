# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `nat_gateway` - The NAT gateways, keyed like `nat_gateways`, each with its `id` (the `nat_gateway_id` of a route to it), `subnet_id`, `connectivity_type`, `allocation_id`, `public_ip` (the address its traffic comes from on the internet, `null` for a private NAT gateway), `private_ip`, `network_interface_id`, `tags` and the rest of its attributes.
    - `eip` - The Elastic IP addresses the module created, keyed like `nat_gateways`, each with its `allocation_id`, `public_ip`, `public_dns`, `tags` and the rest of its attributes, or `null` when the module created none. To find which network interface an address is attached to, use the NAT gateway's `network_interface_id`.
    - `route` - The routes, keyed like `routes`, each with its `route_table_id`, `destination_cidr_block`, `nat_gateway_id` and `state`, or `null` when there are none.
  EOT
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    # One entry per resource.
    eip         = local.output_resources.eip
    nat_gateway = local.output_resources.nat_gateway
    route       = local.output_resources.route
  }
}

locals {
  # Each resource's attributes are listed one by one, and the maps iterate over the
  # input keys, not over the resources. Referencing a whole resource, or iterating
  # over one, would also reference any attribute the provider deprecates later, and
  # every caller's plan would print deprecation warnings.
  output_resources = {
    # Keyed like local.eips: the public NAT gateways without an existing_eip. Left
    # out: association_id, instance, network_interface, private_dns and private_ip.
    # The address is saved before the NAT gateway is attached to it, so these are
    # empty in the state and filled in on the next refresh, and every plan after an
    # apply would show the output changing. The NAT gateway's own attributes have them.
    eip = length(local.eips) == 0 ? null : {
      for k in keys(local.eips) : k => {
        address                   = aws_eip.this[k].address
        allocation_id             = aws_eip.this[k].allocation_id
        arn                       = aws_eip.this[k].arn
        associate_with_private_ip = aws_eip.this[k].associate_with_private_ip
        carrier_ip                = aws_eip.this[k].carrier_ip
        customer_owned_ip         = aws_eip.this[k].customer_owned_ip
        customer_owned_ipv4_pool  = aws_eip.this[k].customer_owned_ipv4_pool
        domain                    = aws_eip.this[k].domain
        id                        = aws_eip.this[k].id
        ipam_pool_id              = aws_eip.this[k].ipam_pool_id
        network_border_group      = aws_eip.this[k].network_border_group
        ptr_record                = aws_eip.this[k].ptr_record
        public_dns                = aws_eip.this[k].public_dns
        public_ip                 = aws_eip.this[k].public_ip
        public_ipv4_pool          = aws_eip.this[k].public_ipv4_pool
        region                    = aws_eip.this[k].region
        tags                      = aws_eip.this[k].tags
        tags_all                  = aws_eip.this[k].tags_all
      }
    }

    # Keyed like var.nat_gateways. Left out: the attributes of regional NAT gateways
    # (availability_mode, availability_zone_address, auto_provision_zones,
    # auto_scaling_ips, regional_nat_gateway_address, regional_nat_gateway_auto_mode,
    # route_table_id) and vpc_id, which are newer than the provider floor; and
    # secondary_allocation_ids, which the module does not set: provider 6.0.0 saves it
    # as null and reads it back as [], so every plan after an apply showed the output
    # changing.
    nat_gateway = {
      for k in keys(var.nat_gateways) : k => {
        allocation_id                      = aws_nat_gateway.this[k].allocation_id
        association_id                     = aws_nat_gateway.this[k].association_id
        connectivity_type                  = aws_nat_gateway.this[k].connectivity_type
        id                                 = aws_nat_gateway.this[k].id
        network_interface_id               = aws_nat_gateway.this[k].network_interface_id
        private_ip                         = aws_nat_gateway.this[k].private_ip
        public_ip                          = aws_nat_gateway.this[k].public_ip
        region                             = aws_nat_gateway.this[k].region
        secondary_private_ip_address_count = aws_nat_gateway.this[k].secondary_private_ip_address_count
        secondary_private_ip_addresses     = aws_nat_gateway.this[k].secondary_private_ip_addresses
        subnet_id                          = aws_nat_gateway.this[k].subnet_id
        tags                               = aws_nat_gateway.this[k].tags
        tags_all                           = aws_nat_gateway.this[k].tags_all
      }
    }

    # Keyed like var.routes. Left out: odb_network_arn, which is newer than the
    # provider floor.
    route = length(var.routes) == 0 ? null : {
      for k in keys(var.routes) : k => {
        carrier_gateway_id          = aws_route.this[k].carrier_gateway_id
        core_network_arn            = aws_route.this[k].core_network_arn
        destination_cidr_block      = aws_route.this[k].destination_cidr_block
        destination_ipv6_cidr_block = aws_route.this[k].destination_ipv6_cidr_block
        destination_prefix_list_id  = aws_route.this[k].destination_prefix_list_id
        egress_only_gateway_id      = aws_route.this[k].egress_only_gateway_id
        gateway_id                  = aws_route.this[k].gateway_id
        id                          = aws_route.this[k].id
        instance_id                 = aws_route.this[k].instance_id
        instance_owner_id           = aws_route.this[k].instance_owner_id
        local_gateway_id            = aws_route.this[k].local_gateway_id
        nat_gateway_id              = aws_route.this[k].nat_gateway_id
        network_interface_id        = aws_route.this[k].network_interface_id
        origin                      = aws_route.this[k].origin
        region                      = aws_route.this[k].region
        route_table_id              = aws_route.this[k].route_table_id
        state                       = aws_route.this[k].state
        transit_gateway_id          = aws_route.this[k].transit_gateway_id
        vpc_endpoint_id             = aws_route.this[k].vpc_endpoint_id
        vpc_peering_connection_id   = aws_route.this[k].vpc_peering_connection_id
      }
    }
  }
}
