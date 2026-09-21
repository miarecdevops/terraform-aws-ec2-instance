package tests

import (
	"context"
	"encoding/json"
	"fmt"
	"net/url"
	"os"
	"strings"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/ec2"
	ec2types "github.com/aws/aws-sdk-go-v2/service/ec2/types"
	"github.com/aws/aws-sdk-go-v2/service/iam"
	"github.com/aws/aws-sdk-go-v2/service/route53"
	r53types "github.com/aws/aws-sdk-go-v2/service/route53/types"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const (
	defaultFlociEndpoint = "http://localhost:4566"
	region               = "us-east-1"
	canonicalOwnerID     = "099720109477"

	// Role passed to the module in every test. Resource names are
	// "<environment>-<role>-<suffix>".
	fixtureRole = "test"
)

// TestDefaultInstance applies the module with only the required inputs and
// checks the instance, its security group, and the outputs.
func TestDefaultInstance(t *testing.T) {
	t.Parallel()

	ctx := t.Context()
	env := uniqueEnvironment()
	opts := fixtureOptions(t, map[string]any{
		"floci_endpoint": flociEndpoint(),
		"environment":    env,
	})
	defer terraform.DestroyContext(t, ctx, opts)
	terraform.InitAndApplyAndIdempotentContext(t, ctx, opts)

	out := terraform.OutputAllContext(t, ctx, opts)
	ec2Client := newEC2Client(flociEndpoint())
	inst := describeInstance(ctx, t, ec2Client, out["instance_id"].(string))

	t.Run("instance", func(t *testing.T) {
		assert.Equal(t, ec2types.InstanceStateNameRunning, inst.State.Name)
		assert.Equal(t, ec2types.InstanceTypeT3Micro, inst.InstanceType)
		assert.Equal(t, env+"-"+fixtureRole+"-key", aws.ToString(inst.KeyName))
		assert.Equal(t, out["subnet_id"], aws.ToString(inst.SubnetId))
		assert.Nil(t, inst.IamInstanceProfile, "no IAM policies were given, so no instance profile should be attached")

		require.NotNil(t, inst.MetadataOptions)
		assert.Equal(t, ec2types.InstanceMetadataEndpointStateEnabled, inst.MetadataOptions.HttpEndpoint)
		assert.Equal(t, ec2types.InstanceMetadataTagsStateEnabled, inst.MetadataOptions.InstanceMetadataTags)
		assert.Equal(t, ec2types.HttpTokensStateRequired, inst.MetadataOptions.HttpTokens, "IMDSv2 should be required")

		assert.Equal(t, map[string]string{
			"Name":        env + "-" + fixtureRole,
			"Role":        fixtureRole,
			"Environment": env,
		}, tagsToMap(inst.Tags))
	})

	t.Run("root volume", func(t *testing.T) {
		vols, err := ec2Client.DescribeVolumes(ctx, &ec2.DescribeVolumesInput{
			Filters: []ec2types.Filter{{Name: aws.String("attachment.instance-id"), Values: []string{aws.ToString(inst.InstanceId)}}},
		})
		require.NoError(t, err)
		require.Len(t, vols.Volumes, 1)
		assert.Equal(t, int32(8), aws.ToInt32(vols.Volumes[0].Size))
	})

	t.Run("AMI is the latest Ubuntu 24.04 from Canonical", func(t *testing.T) {
		image := describeImage(ctx, t, ec2Client, aws.ToString(inst.ImageId))
		assert.Equal(t, canonicalOwnerID, aws.ToString(image.OwnerId))
		assert.Contains(t, aws.ToString(image.Name), "ubuntu-noble-24.04-amd64-server")
	})

	t.Run("security group with default rules", func(t *testing.T) {
		ids := outputStringList(t, out["security_group_ids"])
		require.Len(t, ids, 1)

		sg := describeSecurityGroup(ctx, t, ec2Client, ids[0])
		assert.Equal(t, env+"-"+fixtureRole+"-security_group", aws.ToString(sg.GroupName))
		assert.Equal(t, aws.ToString(inst.VpcId), aws.ToString(sg.VpcId))

		assert.True(t, hasRule(sg.IpPermissions, "tcp", 22, 22, "0.0.0.0/0"), "ingress should allow SSH from anywhere")
		assert.True(t, hasRule(sg.IpPermissionsEgress, "-1", 0, 0, "0.0.0.0/0"), "egress should allow everything")
	})

	t.Run("no Elastic IP", func(t *testing.T) {
		assert.Empty(t, describeAddresses(ctx, t, ec2Client, aws.ToString(inst.InstanceId)))
	})

	t.Run("outputs", func(t *testing.T) {
		assert.Equal(t, aws.ToString(inst.PrivateIpAddress), out["private_ip"])
		assert.Equal(t, aws.ToString(inst.PublicIpAddress), out["public_ip"])
		assert.Equal(t, aws.ToString(inst.Placement.AvailabilityZone), out["az"])
		assert.Equal(t, tagsToMap(inst.Tags), outputStringMap(t, out["instance_tags"]))
		assert.Nil(t, out["fqdn"])
		assert.Nil(t, out["iam_role"])
		assert.Nil(t, out["secondary_private_ip"])
		assert.Nil(t, out["secondary_public_ip"])
	})
}

// TestAMILookup checks the name filter the module builds for each supported
// Ubuntu release, and that an explicit AMI ID wins over the lookup.
func TestAMILookup(t *testing.T) {
	t.Parallel()

	ctx := t.Context()
	ec2Client := newEC2Client(flociEndpoint())

	cases := []struct {
		name         string
		vars         map[string]any
		wantNamePart string
	}{
		{name: "ubuntu 20.04", vars: map[string]any{"ami_os_release": "20.04"}, wantNamePart: "ubuntu-focal-20.04-amd64-server"},
		{name: "ubuntu 22.04", vars: map[string]any{"ami_os_release": "22.04"}, wantNamePart: "ubuntu-jammy-22.04-amd64-server"},
		{name: "ubuntu 24.04", vars: map[string]any{"ami_os_release": "24.04"}, wantNamePart: "ubuntu-noble-24.04-amd64-server"},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			vars := map[string]any{"floci_endpoint": flociEndpoint(), "environment": uniqueEnvironment()}
			for k, v := range tc.vars {
				vars[k] = v
			}
			opts := fixtureOptions(t, vars)
			defer terraform.DestroyContext(t, ctx, opts)
			terraform.InitAndApplyContext(t, ctx, opts)

			inst := describeInstance(ctx, t, ec2Client, terraform.OutputContext(t, ctx, opts, "instance_id"))
			image := describeImage(ctx, t, ec2Client, aws.ToString(inst.ImageId))
			assert.Equal(t, canonicalOwnerID, aws.ToString(image.OwnerId))
			assert.Contains(t, aws.ToString(image.Name), tc.wantNamePart)
		})
	}

	t.Run("explicit AMI ID skips the lookup", func(t *testing.T) {
		t.Parallel()

		// Pick any Canonical image that the default lookup would not choose.
		images, err := ec2Client.DescribeImages(ctx, &ec2.DescribeImagesInput{Owners: []string{canonicalOwnerID}})
		require.NoError(t, err)
		var amiID string
		for _, img := range images.Images {
			if !strings.Contains(aws.ToString(img.Name), "24.04") {
				amiID = aws.ToString(img.ImageId)
				break
			}
		}
		require.NotEmpty(t, amiID, "floci should have a Canonical image other than 24.04")

		opts := fixtureOptions(t, map[string]any{
			"floci_endpoint": flociEndpoint(),
			"environment":    uniqueEnvironment(),
			"ami_id":         amiID,
		})
		defer terraform.DestroyContext(t, ctx, opts)
		terraform.InitAndApplyContext(t, ctx, opts)

		inst := describeInstance(ctx, t, ec2Client, terraform.OutputContext(t, ctx, opts, "instance_id"))
		assert.Equal(t, amiID, aws.ToString(inst.ImageId))
	})
}

// TestElasticIPs attaches an Elastic IP to the instance and another one to a
// secondary private IP.
//
// floci 2.1.0 does not keep secondary private IPs on the instance, so the
// secondary address is checked through the module outputs and the Elastic IP
// allocations only, and the plan is not checked for drift.
func TestElasticIPs(t *testing.T) {
	t.Parallel()

	ctx := t.Context()
	opts := fixtureOptions(t, map[string]any{
		"floci_endpoint":            flociEndpoint(),
		"environment":               uniqueEnvironment(),
		"assign_eip":                true,
		"secondary_private_ip_host": 200,
		"assign_secondary_eip":      true,
	})
	defer terraform.DestroyContext(t, ctx, opts)
	terraform.InitAndApplyContext(t, ctx, opts)

	out := terraform.OutputAllContext(t, ctx, opts)
	ec2Client := newEC2Client(flociEndpoint())
	instanceID := out["instance_id"].(string)

	addresses := describeAddresses(ctx, t, ec2Client, instanceID)
	require.Len(t, addresses, 2, "one Elastic IP for the instance and one for the secondary private IP")

	var publicIPs []string
	for _, a := range addresses {
		publicIPs = append(publicIPs, aws.ToString(a.PublicIp))
	}
	assert.Contains(t, publicIPs, out["public_ip"])
	assert.Contains(t, publicIPs, out["secondary_public_ip"])
	assert.NotEqual(t, out["public_ip"], out["secondary_public_ip"])

	assert.Equal(t, out["expected_secondary_private_ip"], out["secondary_private_ip"])
	assert.NotEqual(t, out["private_ip"], out["secondary_private_ip"])
}

// TestIAMPolicies attaches inline policies through an IAM role and instance
// profile, and checks that the instance uses the profile.
func TestIAMPolicies(t *testing.T) {
	t.Parallel()

	ctx := t.Context()
	env := uniqueEnvironment()
	// The fixture turns each action into a full policy document.
	actions := map[string]string{
		"describe_instances": "ec2:DescribeInstances",
		"read_s3":            "s3:GetObject",
	}
	opts := fixtureOptions(t, map[string]any{
		"floci_endpoint":     flociEndpoint(),
		"environment":        env,
		"iam_policy_actions": actions,
	})
	defer terraform.DestroyContext(t, ctx, opts)
	terraform.InitAndApplyAndIdempotentContext(t, ctx, opts)

	out := terraform.OutputAllContext(t, ctx, opts)
	iamClient := newIAMClient(flociEndpoint())
	roleName := env + "-" + fixtureRole + "-iam_role"
	profileName := env + "-" + fixtureRole + "-iam_instance_policy"

	role, err := iamClient.GetRole(ctx, &iam.GetRoleInput{RoleName: aws.String(roleName)})
	require.NoError(t, err)
	assert.Equal(t, out["iam_role"], aws.ToString(role.Role.Arn))

	t.Run("role trusts EC2", func(t *testing.T) {
		doc := decodePolicyDocument(t, aws.ToString(role.Role.AssumeRolePolicyDocument))
		statements := doc["Statement"].([]any)
		require.Len(t, statements, 1)
		stmt := statements[0].(map[string]any)
		assert.Equal(t, "sts:AssumeRole", stmt["Action"])
		assert.Equal(t, "Allow", stmt["Effect"])
		assert.Equal(t, map[string]any{"Service": "ec2.amazonaws.com"}, stmt["Principal"])
	})

	t.Run("inline policies match the input", func(t *testing.T) {
		list, err := iamClient.ListRolePolicies(ctx, &iam.ListRolePoliciesInput{RoleName: aws.String(roleName)})
		require.NoError(t, err)
		assert.ElementsMatch(t, []string{
			env + "-" + fixtureRole + "-describe_instances-policy",
			env + "-" + fixtureRole + "-read_s3-policy",
		}, list.PolicyNames)

		for key, action := range actions {
			got, err := iamClient.GetRolePolicy(ctx, &iam.GetRolePolicyInput{
				RoleName:   aws.String(roleName),
				PolicyName: aws.String(env + "-" + fixtureRole + "-" + key + "-policy"),
			})
			require.NoError(t, err)
			assert.JSONEq(t, policyDocument(action), urlDecode(t, aws.ToString(got.PolicyDocument)), key)
		}
	})

	t.Run("instance profile is attached to the instance", func(t *testing.T) {
		profile, err := iamClient.GetInstanceProfile(ctx, &iam.GetInstanceProfileInput{InstanceProfileName: aws.String(profileName)})
		require.NoError(t, err)
		require.Len(t, profile.InstanceProfile.Roles, 1)
		assert.Equal(t, roleName, aws.ToString(profile.InstanceProfile.Roles[0].RoleName))

		inst := describeInstance(ctx, t, newEC2Client(flociEndpoint()), out["instance_id"].(string))
		require.NotNil(t, inst.IamInstanceProfile)
		assert.Equal(t, aws.ToString(profile.InstanceProfile.Arn), aws.ToString(inst.IamInstanceProfile.Arn))
	})
}

// TestSecurityGroup covers the two ways to control the instance's security
// groups: custom rules on the group the module creates, or groups passed in
// by the caller.
//
// floci 2.1.0 reports the default security group on every instance, so group
// membership is checked through the module's security_group_ids output.
func TestSecurityGroup(t *testing.T) {
	t.Parallel()

	ctx := t.Context()
	ec2Client := newEC2Client(flociEndpoint())

	t.Run("custom rules replace the defaults", func(t *testing.T) {
		t.Parallel()

		env := uniqueEnvironment()
		opts := fixtureOptions(t, map[string]any{
			"floci_endpoint": flociEndpoint(),
			"environment":    env,
			"sg_rules": map[string]any{
				"HTTP": map[string]any{"type": "ingress", "from_port": "80", "to_port": "80", "protocol": "tcp", "cidr": "10.0.0.0/8"},
				"DNS":  map[string]any{"type": "egress", "from_port": "53", "to_port": "53", "protocol": "udp", "cidr": "10.0.0.0/8"},
			},
		})
		defer terraform.DestroyContext(t, ctx, opts)
		terraform.InitAndApplyAndIdempotentContext(t, ctx, opts)

		ids := terraform.OutputListContext(t, ctx, opts, "security_group_ids")
		require.Len(t, ids, 1)
		sg := describeSecurityGroup(ctx, t, ec2Client, ids[0])
		assert.Equal(t, env+"-"+fixtureRole+"-security_group", aws.ToString(sg.GroupName))

		assert.True(t, hasRule(sg.IpPermissions, "tcp", 80, 80, "10.0.0.0/8"), "custom ingress rule should exist")
		assert.False(t, hasRule(sg.IpPermissions, "tcp", 22, 22, "0.0.0.0/0"), "default SSH rule should be replaced")
		assert.True(t, hasRule(sg.IpPermissionsEgress, "udp", 53, 53, "10.0.0.0/8"), "custom egress rule should exist")
	})

	t.Run("existing group is used and none is created", func(t *testing.T) {
		t.Parallel()

		env := uniqueEnvironment()
		opts := fixtureOptions(t, map[string]any{
			"floci_endpoint":              flociEndpoint(),
			"environment":                 env,
			"use_existing_security_group": true,
		})
		defer terraform.DestroyContext(t, ctx, opts)
		terraform.InitAndApplyAndIdempotentContext(t, ctx, opts)

		out := terraform.OutputAllContext(t, ctx, opts)
		assert.Equal(t, []string{out["existing_security_group_id"].(string)}, outputStringList(t, out["security_group_ids"]))

		groups, err := ec2Client.DescribeSecurityGroups(ctx, &ec2.DescribeSecurityGroupsInput{
			Filters: []ec2types.Filter{{Name: aws.String("group-name"), Values: []string{env + "-" + fixtureRole + "-security_group"}}},
		})
		require.NoError(t, err)
		assert.Empty(t, groups.SecurityGroups, "the module should not create its own security group")
	})
}

// TestRoute53Record creates an A record in a private hosted zone that points
// at the instance's private IP.
func TestRoute53Record(t *testing.T) {
	t.Parallel()

	ctx := t.Context()
	r53Client := newRoute53Client(flociEndpoint())

	cases := []struct {
		name     string
		record   string
		wantFQDN func(zone string) string
	}{
		{name: "host record", record: "this-server", wantFQDN: func(zone string) string { return "this-server." + zone }},
		{name: "zone apex", record: "@", wantFQDN: func(zone string) string { return zone }},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			env := uniqueEnvironment()
			zone := env + ".internal"
			opts := fixtureOptions(t, map[string]any{
				"floci_endpoint":   flociEndpoint(),
				"environment":      env,
				"route53_zone":     zone,
				"route53_a_record": tc.record,
			})
			defer terraform.DestroyContext(t, ctx, opts)
			terraform.InitAndApplyAndIdempotentContext(t, ctx, opts)

			out := terraform.OutputAllContext(t, ctx, opts)
			wantFQDN := tc.wantFQDN(zone)
			assert.Equal(t, wantFQDN, out["fqdn"])

			records, err := r53Client.ListResourceRecordSets(ctx, &route53.ListResourceRecordSetsInput{
				HostedZoneId: aws.String(out["route53_zone_id"].(string)),
			})
			require.NoError(t, err)

			var aRecords []r53types.ResourceRecordSet
			for _, r := range records.ResourceRecordSets {
				if r.Type == r53types.RRTypeA {
					aRecords = append(aRecords, r)
				}
			}
			require.Len(t, aRecords, 1)
			assert.Equal(t, wantFQDN+".", aws.ToString(aRecords[0].Name))
			assert.Equal(t, int64(300), aws.ToInt64(aRecords[0].TTL))
			require.Len(t, aRecords[0].ResourceRecords, 1)
			assert.Equal(t, out["private_ip"], aws.ToString(aRecords[0].ResourceRecords[0].Value), "private zone should resolve to the private IP")
		})
	}
}

// fixtureOptions copies the repository to a temp directory and returns
// options for the instance fixture inside it, so tests can run in parallel.
func fixtureOptions(t *testing.T, vars map[string]any) *terraform.Options {
	t.Helper()
	dir := teststructure.CopyTerraformFolderToTemp(t, "..", "tests/fixtures/instance")
	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: dir,
		Vars:         vars,
	})
}

func flociEndpoint() string {
	if v := os.Getenv("FLOCI_ENDPOINT"); v != "" {
		return v
	}
	return defaultFlociEndpoint
}

func uniqueEnvironment() string {
	return "terratest-" + strings.ToLower(random.UniqueID())
}

func newEC2Client(endpoint string) *ec2.Client {
	return ec2.New(ec2.Options{
		Region:       region,
		BaseEndpoint: aws.String(endpoint),
		Credentials:  credentials.NewStaticCredentialsProvider("test", "test", ""),
	})
}

func newIAMClient(endpoint string) *iam.Client {
	return iam.New(iam.Options{
		Region:       region,
		BaseEndpoint: aws.String(endpoint),
		Credentials:  credentials.NewStaticCredentialsProvider("test", "test", ""),
	})
}

func newRoute53Client(endpoint string) *route53.Client {
	return route53.New(route53.Options{
		Region:       region,
		BaseEndpoint: aws.String(endpoint),
		Credentials:  credentials.NewStaticCredentialsProvider("test", "test", ""),
	})
}

func describeInstance(ctx context.Context, t *testing.T, client *ec2.Client, id string) ec2types.Instance {
	t.Helper()
	out, err := client.DescribeInstances(ctx, &ec2.DescribeInstancesInput{InstanceIds: []string{id}})
	require.NoError(t, err)
	require.Len(t, out.Reservations, 1)
	require.Len(t, out.Reservations[0].Instances, 1)
	return out.Reservations[0].Instances[0]
}

func describeImage(ctx context.Context, t *testing.T, client *ec2.Client, id string) ec2types.Image {
	t.Helper()
	out, err := client.DescribeImages(ctx, &ec2.DescribeImagesInput{ImageIds: []string{id}})
	require.NoError(t, err)
	require.Len(t, out.Images, 1)
	return out.Images[0]
}

func describeSecurityGroup(ctx context.Context, t *testing.T, client *ec2.Client, id string) ec2types.SecurityGroup {
	t.Helper()
	out, err := client.DescribeSecurityGroups(ctx, &ec2.DescribeSecurityGroupsInput{GroupIds: []string{id}})
	require.NoError(t, err)
	require.Len(t, out.SecurityGroups, 1)
	return out.SecurityGroups[0]
}

func describeAddresses(ctx context.Context, t *testing.T, client *ec2.Client, instanceID string) []ec2types.Address {
	t.Helper()
	out, err := client.DescribeAddresses(ctx, &ec2.DescribeAddressesInput{
		Filters: []ec2types.Filter{{Name: aws.String("instance-id"), Values: []string{instanceID}}},
	})
	require.NoError(t, err)
	return out.Addresses
}

// hasRule reports whether a rule with the given protocol, port range, and
// IPv4 CIDR is present. Protocol "-1" means all traffic and has no ports.
func hasRule(perms []ec2types.IpPermission, protocol string, from, to int32, cidr string) bool {
	for _, p := range perms {
		if aws.ToString(p.IpProtocol) != protocol {
			continue
		}
		if protocol != "-1" && (aws.ToInt32(p.FromPort) != from || aws.ToInt32(p.ToPort) != to) {
			continue
		}
		for _, r := range p.IpRanges {
			if aws.ToString(r.CidrIp) == cidr {
				return true
			}
		}
	}
	return false
}

func tagsToMap(tags []ec2types.Tag) map[string]string {
	m := make(map[string]string, len(tags))
	for _, tag := range tags {
		m[aws.ToString(tag.Key)] = aws.ToString(tag.Value)
	}
	return m
}

// outputStringList converts a list output from OutputAll to []string.
func outputStringList(t *testing.T, v any) []string {
	t.Helper()
	items, ok := v.([]any)
	require.True(t, ok, "output should be a list, got %T", v)
	list := make([]string, 0, len(items))
	for _, item := range items {
		list = append(list, item.(string))
	}
	return list
}

// outputStringMap converts a map output from OutputAll to map[string]string.
func outputStringMap(t *testing.T, v any) map[string]string {
	t.Helper()
	items, ok := v.(map[string]any)
	require.True(t, ok, "output should be a map, got %T", v)
	m := make(map[string]string, len(items))
	for k, item := range items {
		m[k] = item.(string)
	}
	return m
}

func policyDocument(action string) string {
	return fmt.Sprintf(`{"Version":"2012-10-17","Statement":[{"Action":%q,"Effect":"Allow","Resource":"*"}]}`, action)
}

// decodePolicyDocument parses a policy document as returned by the IAM API,
// which URL-encodes it.
func decodePolicyDocument(t *testing.T, encoded string) map[string]any {
	t.Helper()
	var doc map[string]any
	require.NoError(t, json.Unmarshal([]byte(urlDecode(t, encoded)), &doc))
	return doc
}

func urlDecode(t *testing.T, s string) string {
	t.Helper()
	decoded, err := url.QueryUnescape(s)
	require.NoError(t, err)
	return decoded
}
