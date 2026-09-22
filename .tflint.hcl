tflint {
  required_version = ">= 0.50"
}

config {
  # Inspect the module when it is called from examples/ and tests/ fixtures.
  call_module_type = "local"

  # stack and environment both default to null so callers can pass either.
  # When tflint inspects the module root on its own, no caller sets them, and
  # a null in a name template is an error. Give stack a placeholder value.
  variables = ["stack=tflint"]
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
