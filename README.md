# Terraform module for Amazon VPC NAT gateways

Creates NAT gateways for an Amazon Virtual Private Cloud (VPC), and the routes that send traffic to them. A NAT gateway lets instances in a private subnet open connections to the internet, or to other networks, without a public IP address of their own. Nothing outside can open a connection back to them through it.

You list the NAT gateways by name, each in a subnet you choose, and the route tables that use each one. The module creates nothing else in the VPC, so it works with a VPC from any source, including one created in the same configuration.

## What it configures

| Setting | Default | Input |
|---|---|---|
| NAT gateways | One per entry, in the subnet you give | `nat_gateways` (required) |
| Connectivity | `public`: through an Elastic IP address, to the internet | `nat_gateways.<name>.connectivity_type` |
| Elastic IP address | A new one for each public NAT gateway, released with it | `nat_gateways.<name>.existing_eip` |
| `Name` tag | `<scope>-<purpose>-<environment>-<region>-<name>` | `nat_gateways.<name>.name` |
| Routes | None: nothing uses a NAT gateway until a route table sends traffic to it | `routes` |
| Route destination | `0.0.0.0/0`, all IPv4 traffic no more specific route covers | `routes.<name>.destination_cidr_block` |

## Usage

```hcl
module "nat_gateway" {
  source  = "AutomateTheCloud/nat_gateway/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Web Site"
    environment = "Production"
  }

  # One NAT gateway in each Availability Zone, each in a public subnet.
  nat_gateways = {
    a = { subnet_id = aws_subnet.public_a.id }
    b = { subnet_id = aws_subnet.public_b.id }
  }

  # Each private route table sends its internet traffic to the NAT gateway in its own zone.
  routes = {
    private_a = { route_table_id = aws_route_table.private_a.id, nat_gateway = "a" }
    private_b = { route_table_id = aws_route_table.private_b.id, nat_gateway = "b" }
  }
}
```

`details` and `nat_gateways` are the only required inputs. `details` sets the `Scope`, `Purpose` and `Environment` tags, and the `Name` tags, here `automate_the_cloud-web_site-production-use1-a` and `-b`.

The module uses your default `aws` provider and creates everything in that provider's Region. To create the NAT gateways somewhere else without configuring another provider, set `region`; the subnets and route tables must be in that Region too:

```hcl
module "nat_gateway_us_west_2" {
  source  = "AutomateTheCloud/nat_gateway/aws"
  version = "~> 1.0"

  region  = "us-west-2"
  details = { scope = "Automate the Cloud", purpose = "Web Site", environment = "Production" }

  nat_gateways = { a = { subnet_id = "subnet-0123456789abcdef0" } }
  routes       = { private_a = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a" } }
}
```

Because `region` is an ordinary input, one module block can create NAT gateways in each of several Regions with `for_each`.

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the NAT gateways belong to, what they are for, and which environment they are in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Web Site"           # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at a NAT gateway in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the NAT gateways, the VPC they serve, its DNS zone and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Web Site"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "site_nat_gateway" {
  source  = "AutomateTheCloud/nat_gateway/aws"
  version = "~> 1.0"

  details      = local.details
  nat_gateways = { a = { subnet_id = aws_subnet.public_a.id } }
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Web Site` becomes `web_site`), and `machine`, lowercase letters and numbers only (`website`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.site_nat_gateway.metadata.nat_gateway["a"].public_ip` for the address that NAT gateway's traffic comes from, or `module.site_nat_gateway.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration you can run with `terraform init` and `terraform apply`. NAT gateways and public IPv4 addresses are billed by the hour, so destroy an example when you are done with it.

- [Basic NAT gateway](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/tree/main/examples/basic): one NAT gateway for a private subnet, in a small VPC built in the example.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/tree/main/examples/complete): a NAT gateway in each of two Availability Zones, each private route table sent to its own zone's NAT gateway, one NAT gateway with an Elastic IP address managed outside the module.

## Things to know

### Where to put NAT gateways

A NAT gateway lives in one Availability Zone, the zone of its subnet. Create one in each zone that has private subnets, and send each private route table to the NAT gateway in its own zone. Traffic to a NAT gateway in another zone is billed for data transfer between zones, and stops if that zone has a problem. One NAT gateway for every zone, as in the [basic example](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/tree/main/examples/basic), costs less, and suits environments that can accept that.

A public NAT gateway must be in a public subnet, one whose route table sends `0.0.0.0/0` to an internet gateway, and the VPC's internet gateway must exist before the NAT gateway is created. When the internet gateway is in the same configuration, add `depends_on = [aws_internet_gateway.this]` to the module block, as the examples do.

### Routes

Each route names its route table and its NAT gateway, so the module never has to look up which subnet uses which route table, and a route table created in the same configuration can be used. A subnet that has no route table of its own uses the VPC's main route table; list the main route table to reach it.

A route table can hold only one route for each destination. The plan fails if `routes` lists the same route table and destination twice, and the apply fails if the route table already has a route for that destination from somewhere else, such as a default route to an internet gateway.

### Elastic IP addresses

Each public NAT gateway sends its traffic from one Elastic IP address. By default the module creates the address, and releases it when the NAT gateway is removed; the next address will be different. If the address must stay the same, for example because a partner allows it through a firewall, create it outside the module and pass it in as `existing_eip`. Destroying the module then leaves the address in your account.

Each AWS account can have five Elastic IP addresses per Region unless you ask AWS for more.

### Changing a NAT gateway

Changing a NAT gateway's `subnet_id`, `connectivity_type` or `existing_eip` replaces it. Traffic through it stops until the new NAT gateway is available, which takes a few minutes, and the routes are updated to point to it in place. When only `subnet_id` changes, the new NAT gateway keeps the same Elastic IP address. Removing an entry from `nat_gateways` removes only that NAT gateway; the others are not touched. Changing only `details` or `name` updates the tags in place.

### Removing a public NAT gateway

When a public NAT gateway is deleted, AWS keeps its Elastic IP address attached to the NAT gateway's network interface for a few more minutes, while it deletes the interface. If Terraform releases the address in that time, which it does when the module created the address, or when you destroy your own `aws_eip` with the module, the release fails:

```
Error: deleting EC2 EIP (eipalloc-...): ... InvalidNetworkInterfaceID.NotFound: The networkInterface ID 'eni-...' does not exist
```

The NAT gateway is already deleted, and nothing else is left half done. Wait a few minutes and run the same `terraform apply` or `terraform destroy` again: it releases the address and finishes. In our tests the address stayed attached for two to six minutes.

### Private NAT gateways

A NAT gateway with `connectivity_type = "private"` has no public address and does not reach the internet. It lets instances reach other VPCs or an on-premises network through a transit gateway or a virtual private gateway, using the NAT gateway's private IP address, for example when the two networks' address ranges overlap. Send it only the address ranges of those networks, with `destination_cidr_block`.

### Not covered

The module creates zonal NAT gateways only. Regional NAT gateways, which span Availability Zones on their own, need a newer AWS provider than this module's minimum, version 6.0. It also does not set secondary IP addresses, or routes for IPv6 (NAT64).

### Cost

AWS bills each NAT gateway by the hour while it exists, and for each gigabyte it processes, and bills each public IPv4 address by the hour. See [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/). Traffic from private subnets to Amazon S3 or Amazon DynamoDB in the same Region can avoid the NAT gateway through a gateway VPC endpoint, which costs nothing.

### With the Automate the Cloud VPC module

The [VPC module](https://registry.terraform.io/modules/AutomateTheCloud/vpc/aws/latest) creates three public subnets and three private route tables, one in each Availability Zone, and no NAT gateway. To give its private subnets internet access:

```hcl
module "nat_gateway" {
  source  = "AutomateTheCloud/nat_gateway/aws"
  version = "~> 1.0"

  details = local.details

  nat_gateways = {
    for zone in ["1", "2", "3"] : zone => { subnet_id = module.vpc.metadata.subnet.public[zone].id }
  }
  routes = {
    for zone in ["1", "2", "3"] : "private_${zone}" => {
      route_table_id = module.vpc.metadata.route_table.private[zone].id
      nat_gateway    = zone
    }
  }
}
```

The VPC module's network ACLs deny all traffic until you add rules, so also allow the private subnets' outbound traffic and its replies through both the private and the public tiers' network ACLs.

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web Site`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_nat_gateways"></a> [nat_gateways](#input_nat_gateways)

Description: The NAT gateways to create, as a map of names you choose to settings, such as `{ a = { subnet_id = "subnet-0123456789abcdef0" } }`. `routes` refers to each NAT gateway by its name, and the name ends its default `Name` tag. A NAT gateway is in one Availability Zone, the zone of its subnet; for a VPC that uses several zones, create one in each.

- `subnet_id` - (Required) The subnet to create the NAT gateway in, such as `subnet-0123456789abcdef0`. For a public NAT gateway, use a public subnet: one whose route table sends `0.0.0.0/0` to an internet gateway.
- `connectivity_type` - (Optional) `public` or `private`. Defaults to `public`: the NAT gateway gives instances in private subnets access to the internet through an Elastic IP address. A `private` NAT gateway has no public address; it reaches other VPCs or an on-premises network through a transit gateway or a virtual private gateway.
- `existing_eip` - (Optional) For a public NAT gateway, an Elastic IP address you already have, as `{ allocation_id = "eipalloc-0123456789abcdef0" }`. Destroying the module then leaves the address in your account. Defaults to `null`: the module creates an Elastic IP address for each public NAT gateway, and releases it when the NAT gateway is removed.
- `name` - (Optional) The `Name` tag of the NAT gateway and of the Elastic IP address the module creates for it. Defaults to `<scope>-<purpose>-<environment>-<region>-<name>`, from the `details` abbreviations and the map key, such as `automate_the_cloud-web_site-production-use1-a`.

Changing `subnet_id`, `connectivity_type` or `existing_eip` replaces the NAT gateway. Traffic through it stops until the new NAT gateway is available and the routes point to it.

Type:

```hcl
map(object({
    subnet_id         = string
    connectivity_type = optional(string, "public")
    existing_eip = optional(object({
      allocation_id = string
    }))
    name = optional(string)
  }))
```

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the NAT gateways, Elastic IP addresses and routes in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. Every subnet, route table and existing Elastic IP address must be in this Region.

Type: `string`

Default: `null`

#### <a name="input_routes"></a> [routes](#input_routes)

Description: Routes that send traffic from a route table to one of the NAT gateways, as a map of names you choose to settings, such as `{ private_a = { route_table_id = "rtb-0123456789abcdef0", nat_gateway = "a" } }`. The names only identify each route, so a route table created in the same configuration can be used. Defaults to none: until a route table sends traffic to a NAT gateway, nothing uses it.

- `route_table_id` - (Required) The route table to add the route to, such as `rtb-0123456789abcdef0`: the route table of the private subnets that use the NAT gateway.
- `nat_gateway` - (Required) The name of the NAT gateway in `nat_gateways` to send the traffic to. Use the NAT gateway in the same Availability Zone as the route table's subnets: traffic to a NAT gateway in another zone is billed for data transfer between zones, and stops when that zone fails.
- `destination_cidr_block` - (Optional) The IPv4 range to send to the NAT gateway, in CIDR notation, such as `10.20.0.0/16`. Defaults to `0.0.0.0/0`: all IPv4 traffic that no more specific route covers.

Each route table can have only one route for each destination.

Type:

```hcl
map(object({
    route_table_id         = string
    nat_gateway            = string
    destination_cidr_block = optional(string, "0.0.0.0/0")
  }))
```

Default: `{}`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

- `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
- `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
- `nat_gateway` - The NAT gateways, keyed like `nat_gateways`, each with its `id` (the `nat_gateway_id` of a route to it), `subnet_id`, `connectivity_type`, `allocation_id`, `public_ip` (the address its traffic comes from on the internet, `null` for a private NAT gateway), `private_ip`, `network_interface_id`, `tags` and the rest of its attributes.
- `eip` - The Elastic IP addresses the module created, keyed like `nat_gateways`, each with its `allocation_id`, `public_ip`, `public_dns`, `tags` and the rest of its attributes, or `null` when the module created none. To find which network interface an address is attached to, use the NAT gateway's `network_interface_id`.
- `route` - The routes, keyed like `routes`, each with its `route_table_id`, `destination_cidr_block`, `nat_gateway_id` and `state`, or `null` when there are none.
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
