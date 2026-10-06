# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "nat_gateways" {
  description = <<-EOT
    The NAT gateways to create, as a map of names you choose to settings, such as `{ a = { subnet_id = "subnet-0123456789abcdef0" } }`. `routes` refers to each NAT gateway by its name, and the name ends its default `Name` tag. A NAT gateway is in one Availability Zone, the zone of its subnet; for a VPC that uses several zones, create one in each.

    - `subnet_id` - (Required) The subnet to create the NAT gateway in, such as `subnet-0123456789abcdef0`. For a public NAT gateway, use a public subnet: one whose route table sends `0.0.0.0/0` to an internet gateway.
    - `connectivity_type` - (Optional) `public` or `private`. Defaults to `public`: the NAT gateway gives instances in private subnets access to the internet through an Elastic IP address. A `private` NAT gateway has no public address; it reaches other VPCs or an on-premises network through a transit gateway or a virtual private gateway.
    - `existing_eip` - (Optional) For a public NAT gateway, an Elastic IP address you already have, as `{ allocation_id = "eipalloc-0123456789abcdef0" }`. Destroying the module then leaves the address in your account. Defaults to `null`: the module creates an Elastic IP address for each public NAT gateway, and releases it when the NAT gateway is removed.
    - `name` - (Optional) The `Name` tag of the NAT gateway and of the Elastic IP address the module creates for it. Defaults to `<scope>-<purpose>-<environment>-<region>-<name>`, from the `details` abbreviations and the map key, such as `automate_the_cloud-web_site-production-use1-a`.

    Changing `subnet_id`, `connectivity_type` or `existing_eip` replaces the NAT gateway. Traffic through it stops until the new NAT gateway is available and the routes point to it.
  EOT
  type = map(object({
    subnet_id         = string
    connectivity_type = optional(string, "public")
    existing_eip = optional(object({
      allocation_id = string
    }))
    name = optional(string)
  }))
  nullable = false

  validation {
    condition     = length(var.nat_gateways) > 0
    error_message = "nat_gateways must list at least one NAT gateway."
  }

  validation {
    condition     = alltrue([for k in keys(var.nat_gateways) : can(regex("^[0-9A-Za-z_-]+$", k))])
    error_message = "Each nat_gateways name must contain only letters, numbers, hyphens and underscores, such as a or use1-az1."
  }

  validation {
    condition     = alltrue([for v in values(var.nat_gateways) : can(regex("^subnet-[0-9a-f]{8}([0-9a-f]{9})?$", v.subnet_id))])
    error_message = "Each nat_gateways subnet_id must be a subnet ID, such as subnet-0123456789abcdef0."
  }

  validation {
    condition     = alltrue([for v in values(var.nat_gateways) : contains(["public", "private"], v.connectivity_type)])
    error_message = "Each nat_gateways connectivity_type must be public or private."
  }

  validation {
    condition     = alltrue([for v in values(var.nat_gateways) : v.existing_eip == null || v.connectivity_type == "public"])
    error_message = "existing_eip can be set only on a public NAT gateway. A private NAT gateway has no Elastic IP address."
  }

  validation {
    condition     = alltrue([for v in values(var.nat_gateways) : v.existing_eip == null || can(regex("^eipalloc-[0-9a-f]{8}([0-9a-f]{9})?$", v.existing_eip.allocation_id))])
    error_message = "Each nat_gateways existing_eip.allocation_id must be an Elastic IP allocation ID, such as eipalloc-0123456789abcdef0."
  }

  validation {
    condition     = length(distinct([for v in values(var.nat_gateways) : v.existing_eip.allocation_id if v.existing_eip != null])) == length([for v in values(var.nat_gateways) : v if v.existing_eip != null])
    error_message = "nat_gateways uses an existing_eip more than once. An Elastic IP address can belong to only one NAT gateway."
  }

  validation {
    condition     = alltrue([for v in values(var.nat_gateways) : v.name == null || try(trimspace(v.name) != "" && length(v.name) <= 256, false)])
    error_message = "Each nat_gateways name must be 1 to 256 characters, the limit for a tag value. Leave it out for the default name."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the NAT gateways, Elastic IP addresses and routes in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. Every subnet, route table and existing Elastic IP address must be in this Region.
  EOT
  type        = string
  default     = null
}

variable "routes" {
  description = <<-EOT
    Routes that send traffic from a route table to one of the NAT gateways, as a map of names you choose to settings, such as `{ private_a = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a" } }`. The names only identify each route, so a route table created in the same configuration can be used. Defaults to none: until a route table sends traffic to a NAT gateway, nothing uses it.

    - `route_table_id` - (Required) The route table to add the route to, such as `rtb-0123456789abcdef0`: the route table of the private subnets that use the NAT gateway.
    - `nat_gateway` - (Required) The name of the NAT gateway in `nat_gateways` to send the traffic to. Use the NAT gateway in the same Availability Zone as the route table's subnets: traffic to a NAT gateway in another zone is billed for data transfer between zones, and stops when that zone fails.
    - `destination_cidr_block` - (Optional) The IPv4 range to send to the NAT gateway, in CIDR notation, such as `10.20.0.0/16`. Defaults to `0.0.0.0/0`: all IPv4 traffic that no more specific route covers.

    Each route table can have only one route for each destination.
  EOT
  type = map(object({
    route_table_id         = string
    nat_gateway            = string
    destination_cidr_block = optional(string, "0.0.0.0/0")
  }))
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for v in values(var.routes) : can(regex("^rtb-[0-9a-f]{8}([0-9a-f]{9})?$", v.route_table_id))])
    error_message = "Each routes route_table_id must be a route table ID, such as rtb-0123456789abcdef0."
  }

  validation {
    condition     = alltrue([for v in values(var.routes) : contains(keys(var.nat_gateways), v.nat_gateway)])
    error_message = "Each routes nat_gateway must be the name of a NAT gateway in nat_gateways."
  }

  validation {
    condition     = alltrue([for v in values(var.routes) : can(cidrnetmask(v.destination_cidr_block)) && try(cidrsubnet(v.destination_cidr_block, 0, 0) == v.destination_cidr_block, false)])
    error_message = "Each routes destination_cidr_block must be an IPv4 network in CIDR notation, such as 0.0.0.0/0 or 10.20.0.0/16, with no host bits set (10.20.0.0/16, not 10.20.1.0/16)."
  }

  validation {
    condition     = length(distinct([for v in values(var.routes) : "${v.route_table_id} ${v.destination_cidr_block}"])) == length(var.routes)
    error_message = "routes lists the same route_table_id and destination_cidr_block more than once. A route table can hold only one route for each destination."
  }
}
