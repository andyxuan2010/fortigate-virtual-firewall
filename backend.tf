// Environment-specific backend settings are supplied through
// environments/<environment>/backend.hcl (or the CI pipeline).
terraform {
  backend "azurerm" {}
}

# local backend for testing
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }