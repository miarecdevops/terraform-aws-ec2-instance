# Tests

The tests are written in Go with [Terratest](https://github.com/gruntwork-io/terratest). There are two suites.

## Local suite against floci

`instance_test.go` applies the module through the root module in `fixtures/instance` against [floci](https://github.com/floci-io/floci), a free and open-source AWS emulator running in Docker. It needs no AWS account and runs on every push in GitHub Actions.

From the repository root:

```bash
mise install
mise run test
```

The task starts a floci container for this checkout if one is not running, exports its URL as `FLOCI_ENDPOINT`, and runs `go test`. To run a single test:

```bash
export FLOCI_ENDPOINT="$(mise run -q floci-url)"
cd tests
go test -v -count=1 -run TestIAMPolicies ./...
```

The tests cover:

- **Default instance.** Instance type, key pair, tags, root volume size, metadata options, the latest Ubuntu 24.04 AMI from Canonical, the security group with the default SSH and egress rules, and every module output. Also checks that a second `terraform plan` is empty.
- **AMI lookup.** The name filter for Ubuntu 20.04, 22.04, and 24.04, and that an explicit AMI ID skips the lookup.
- **Elastic IPs.** One Elastic IP on the instance and one on a secondary private IP.
- **IAM policies.** The role, its trust policy, the inline policies, the instance profile, and that the instance uses the profile.
- **Security group.** Custom rules replace the default ones, and a group passed by the caller is used without creating a new one.
- **Route53 record.** An A record in a private hosted zone that points at the private IP, for a host name and for the zone apex.

floci 2.1.0 differs from AWS in two ways that the tests work around:

- It ignores the security groups passed to `RunInstances` and reports the default group on every instance. Group membership is checked through the module's `security_group_ids` output instead.
- It does not keep secondary private IPs on the instance. The secondary address is checked through the module outputs and the Elastic IP allocations, and that test skips the empty-plan check.

## Real AWS suite

`aws_examples_test.go` deploys every directory under `examples/` to a real AWS account, then connects to the instance over SSH with the generated key and runs commands. It is behind the `aws` build tag, so `go test ./...` skips it.

**These tests create real resources and cost money.** They try to destroy everything at the end. Do not stop them with `Ctrl+C`, or the resources stay behind.

Set AWS credentials in the environment, then run:

```bash
mise run test:aws
```

Each example is deployed to one of the four US regions (`us-east-1`, `us-east-2`, `us-west-1`, `us-west-2`), chosen at random, with an instance type that is available there. The list is `usRegions` in `aws_examples_test.go`.
