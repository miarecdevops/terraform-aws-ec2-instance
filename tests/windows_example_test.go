package tests

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

func TestWindowsExamplePlan(t *testing.T) {
	t.Parallel()

	exampleFolder := test_structure.CopyTerraformFolderToTemp(t, "../", "examples/windows")

	releases := []string{"2022", "2019"}
	for _, release := range releases {
		release := release
		t.Run(fmt.Sprintf("release_%s", release), func(t *testing.T) {
			awsRegion := aws.GetRandomStableRegion(t, nil, nil)
			if _, err := aws.GetAccountIdE(t); err != nil {
				t.Skipf("skipping Windows plan test due to missing AWS credentials: %v", err)
			}

			terraformOptions := configureWindowsPlanOptions(t, exampleFolder, release, awsRegion)

			terraform.Init(t, terraformOptions)
			planOutput := terraform.Plan(t, terraformOptions)

			expectedMarker := fmt.Sprintf("Windows_Server-%s-English-Full-Base", release)
			require.Contains(t, planOutput, expectedMarker)
		})
	}
}

func configureWindowsPlanOptions(t *testing.T, exampleFolder string, release string, awsRegion string) *terraform.Options {
	uniqueID := random.UniqueId()
	environmentName := fmt.Sprintf("terratest-windows-%s", uniqueID)

	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: exampleFolder,
		Vars: map[string]interface{}{
			"environment":        environmentName,
			"aws_region":         awsRegion,
			"ec2_ami_os_release": release,
			"rdp_source_cidr":    "10.0.0.0/8",
			"instance_type":      "m6i.large",
			"volume_size":        80,
			"tags": map[string]string{
				"Purpose": "terratest",
			},
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	})
}
