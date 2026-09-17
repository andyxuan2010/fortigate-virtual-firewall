#!/usr/bin/env bash

set -euo pipefail

backend_subscription_id="${1:?backend subscription id is required}"
backend_tenant_id="${2:?backend tenant id is required}"
backend_resource_group_name="${3:?backend resource group name is required}"
backend_storage_account_name="${4:?backend storage account name is required}"
backend_container_name="${5:?backend container name is required}"
backend_key="${6:?backend key is required}"
var_file="${7:?variable file path is required}"
plan_file="${8:?plan file path is required}"
plan_text_file="${9:?plan text file path is required}"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/terraform-common.sh"
configure_arm_auth

# Azure DevOps leaves an undefined $(VARIABLE) reference as literal text.
# Treat unresolved optional secret mappings as unset Terraform variables.
for optional_secret in \
  TF_VAR_fortigate_admin_password \
  TF_VAR_fortigate_admin_ssh_public_key; do
  value="${!optional_secret:-}"
  if [[ "${value}" == \$\(*\) ]]; then
    unset "${optional_secret}"
  fi
done

mkdir -p "$(dirname "${plan_file}")"
mkdir -p "$(dirname "${plan_text_file}")"

terraform version
terraform init \
  -reconfigure \
  -input=false \
  -no-color \
  -backend-config="subscription_id=${backend_subscription_id}" \
  -backend-config="tenant_id=${backend_tenant_id}" \
  -backend-config="resource_group_name=${backend_resource_group_name}" \
  -backend-config="storage_account_name=${backend_storage_account_name}" \
  -backend-config="container_name=${backend_container_name}" \
  -backend-config="key=${backend_key}"

fortigate_enabled="$(
  printf '%s\n' 'lookup(var.features, "enable_fortigate", false)' |
    terraform console -no-color -var-file="${var_file}"
)"

if [[ "${fortigate_enabled}" == "true" ]] &&
  [[ -z "${TF_VAR_fortigate_admin_password:-}" ]] &&
  [[ -z "${TF_VAR_fortigate_admin_ssh_public_key:-}" ]]; then
  echo "FortiGate pipeline credentials are not configured; Terraform will use the shared IaC Key Vault fallback secrets."
fi

terraform plan -input=false -no-color -var-file="${var_file}" -out="${plan_file}"
terraform show -no-color "${plan_file}" > "${plan_text_file}"
bash "${script_dir}/../common/terraform-change-summary.sh" "${plan_file}" "Terraform plan summary"
