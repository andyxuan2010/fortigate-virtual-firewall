// Environment-specific backend settings are supplied through
// platforms/azure/environments/<environment>/backend.hcl (or the CI pipeline).
terraform {
  backend "azurerm" {}
}

# local backend for testing
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }