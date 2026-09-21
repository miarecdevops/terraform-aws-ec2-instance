tflint {
  required_version = ">= 0.50"
}

config {
  # Inspect the module when it is called from examples/ and tests/ fixtures.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.49.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
