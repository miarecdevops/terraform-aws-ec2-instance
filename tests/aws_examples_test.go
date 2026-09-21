//go:build aws

package tests

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	teststructure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

// usRegions are the only regions the real-AWS suite deploys to.
var usRegions = []string{"us-east-1", "us-east-2", "us-west-1", "us-west-2"}

// TestExamplesOnAWS deploys every example to a real AWS account, then checks
// that the instance accepts SSH connections with the generated key and runs
// commands.
//
// It costs money and needs AWS credentials in the environment. It is behind
// the "aws" build tag: run it with `mise run test:aws`.
func TestExamplesOnAWS(t *testing.T) {
	t.Parallel()

	for _, example := range []string{"default-vpc", "custom-vpc", "iam-policies", "route53"} {
		t.Run(example, func(t *testing.T) {
			t.Parallel()

			ctx := t.Context()
			exampleDir := teststructure.CopyTerraformFolderToTemp(t, "..", filepath.Join("examples", example))

			// Pick a random US region so the code is exercised outside the
			// default one, and an instance type that exists there.
			awsRegion := aws.GetRandomStableRegionContext(t, ctx, usRegions, nil)
			instanceType := aws.GetRecommendedInstanceTypeContext(t, ctx, awsRegion, []string{"t2.micro", "t3.micro"})

			vars := map[string]any{
				"environment":   "terratest-" + example + "-" + strings.ToLower(random.UniqueID()),
				"aws_region":    awsRegion,
				"instance_type": instanceType,
			}
			if example == "custom-vpc" {
				// The example defaults to us-west-2a. Use a zone that exists
				// in the region that was picked.
				vars["availability_zones"] = aws.GetAvailabilityZonesContext(t, ctx, awsRegion)[:1]
			}

			opts := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
				TerraformDir: exampleDir,
				Vars:         vars,
			})
			defer terraform.DestroyContext(t, ctx, opts)
			terraform.InitAndApplyContext(t, ctx, opts)

			keyPair, err := rsaKeyPairFromFile(filepath.Join(exampleDir, "priv_key.pem"))
			require.NoError(t, err)

			publicIP := terraform.OutputContext(t, ctx, opts, "public_ip")
			checkSSHToHost(ctx, t, publicIP, keyPair)
		})
	}
}
