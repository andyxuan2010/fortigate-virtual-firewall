bucket         = "REPLACE_WITH_TERRAFORM_STATE_BUCKET"
key            = "fortigate-virtual-firewall/aws/prod/terraform.tfstate"
region         = "us-east-1"
encrypt        = true
dynamodb_table = "REPLACE_WITH_TERRAFORM_LOCK_TABLE"
