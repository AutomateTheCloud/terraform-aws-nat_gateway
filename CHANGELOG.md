# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.1] - 2026-10-06

### Changed

- The copyright year in `NOTICE` and the file headers is now 2026, the year the module was rebuilt and released as 1.0.0.
- `CLAUDE.md`, the working rules shared by every Automate the Cloud module, adds the lessons learned while rebuilding the modules.

## [1.0.0] - 2026-10-05

Initial release.

### Added

- Amazon VPC NAT gateways, as a map keyed by names you choose, so adding or removing one leaves the others alone.
- Public NAT gateways, each with an Elastic IP address the module creates or one you already have, and private NAT gateways with no public address.
- Routes from the route tables you list to the NAT gateway each one names, for `0.0.0.0/0` or another IPv4 range. A route table created in the same configuration can be used.
- Checks at plan time for IDs, connectivity types, routes that name an unknown NAT gateway, and a route table listed twice for the same destination.
- `region`, to create everything in a Region other than the provider's.
- A `metadata` output with everything the module created.
- Offline tests, and examples for one NAT gateway and for a NAT gateway in each of two Availability Zones.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-nat_gateway/releases/tag/v1.0.0
