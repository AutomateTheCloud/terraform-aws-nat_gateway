# Complete

A public NAT gateway in each of the first two Availability Zones of `us-east-1`, and a private subnet in each zone whose route table sends all IPv4 traffic to the NAT gateway in the same zone. If one zone has a problem, the private subnet in the other zone keeps its internet access, and no traffic crosses between zones.

- NAT gateway `a` uses an Elastic IP address created outside the module (`aws_eip.a`). The address stays the same if the NAT gateway is replaced, and is not released when the module is destroyed, so it suits an address that a partner has on an allow list.
- NAT gateway `b` gets an Elastic IP address from the module.
- Both have a chosen `Name` tag, and every resource gets the `CostCenter` tag from `additional_tags`.

Each NAT gateway and each public IPv4 address is billed by the hour while it exists, and each NAT gateway also for each gigabyte it processes; see [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/).

## Run it

```shell
terraform init
terraform apply
```

Remove it with `terraform destroy`. The Elastic IP address `aws_eip.a` is part of this example, so it is released too.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Outputs

The following outputs are exported:

#### <a name="output_nat_gateway_public_ips"></a> [nat_gateway_public_ips](#output_nat_gateway_public_ips)

Description: The address that traffic from each zone's private subnet comes from on the internet
<!-- END_TF_DOCS -->
