# Basic NAT gateway

One public NAT gateway, in the first Availability Zone of `us-east-1`, that gives instances in a private subnet access to the internet. The example builds a small VPC around it: a public subnet with a route to an internet gateway, where the NAT gateway goes, and a private subnet whose route table sends all IPv4 traffic (`0.0.0.0/0`) to the NAT gateway. The module creates the NAT gateway's Elastic IP address and the route.

Instances in the private subnet can open connections to the internet, and their traffic comes from the address in the `nat_gateway_public_ip` output. Nothing on the internet can open a connection to them.

A NAT gateway and its public IPv4 address are billed by the hour while they exist, and the NAT gateway also for each gigabyte it processes; see [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/).

## Run it

```shell
terraform init
terraform apply
```

Remove it with `terraform destroy`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Outputs

The following outputs are exported:

#### <a name="output_nat_gateway_public_ip"></a> [nat_gateway_public_ip](#output_nat_gateway_public_ip)

Description: The address that traffic from the private subnet comes from on the internet
<!-- END_TF_DOCS -->
