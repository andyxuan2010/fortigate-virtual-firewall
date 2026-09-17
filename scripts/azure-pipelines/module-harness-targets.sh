#!/usr/bin/env bash

set -euo pipefail

MODULES=(
  acr
  adf
  aks
  appregistration
  appservice
  appserviceplan
  applicationgateway
  automationaccount
  azure_ai_service
  azure_ai_search
  cosmosdb
  databricks
  enterpriseapplication
  eventhub
  firewall
  functionapp
  keyvault
  linuxvm
  loganalytics
  logicapp
  managedidentity
  managementgroups
  nsg
  openai
  policy
  private_dns
  rg
  roleassignments
  route_table
  servicebus
  sqldb
  sqlmi
  sqlmi_db
  storageaccount
  subscription_vending
  vnet
  winvm
)

declare -A MODULE_LOOKUP=()
for module in "${MODULES[@]}"; do
  MODULE_LOOKUP["$module"]=1
done

empty_tree_hash() {
  git hash-object -t tree /dev/null
}

normalize_base_ref() {
  local base_ref="$1"
  local head_ref="$2"

  if [[ -z "${base_ref}" || "${base_ref}" =~ ^0+$ ]]; then
    if git rev-parse --verify "${head_ref}^" >/dev/null 2>&1; then
      printf '%s\n' "${head_ref}^"
    else
      empty_tree_hash
    fi
    return
  fi

  if git rev-parse --verify "${base_ref}^{commit}" >/dev/null 2>&1; then
    printf '%s\n' "${base_ref}"
    return
  fi

  if git rev-parse --verify "origin/${base_ref#refs/heads/}^{commit}" >/dev/null 2>&1; then
    printf '%s\n' "origin/${base_ref#refs/heads/}"
    return
  fi

  if git rev-parse --verify "${head_ref}^" >/dev/null 2>&1; then
    printf '%s\n' "${head_ref}^"
  else
    empty_tree_hash
  fi
}

is_known_module() {
  local module_name="$1"
  [[ -n "${MODULE_LOOKUP[$module_name]:-}" ]]
}

expand_related_modules() {
  local module_name="$1"

  printf '%s\n' "${module_name}"

  case "${module_name}" in
    appservice)
      printf '%s\n' "appserviceplan"
      ;;
    enterpriseapplication)
      printf '%s\n' "appregistration"
      ;;
    functionapp | logicapp)
      printf '%s\n' "appserviceplan"
      printf '%s\n' "storageaccount"
      ;;
    sqlmi)
      printf '%s\n' "vnet"
      ;;
    sqlmi_db)
      printf '%s\n' "sqlmi"
      printf '%s\n' "vnet"
      ;;
  esac
}

select_modules_from_changed_files() {
  declare -A selected=()
  local run_all=false
  local changed_file

  while IFS= read -r changed_file; do
    [[ -z "${changed_file}" ]] && continue

    case "${changed_file}" in
      modules/*)
        local module_name="${changed_file#modules/}"
        module_name="${module_name%%/*}"
        if is_known_module "${module_name}"; then
          selected["${module_name}"]=1
        else
          run_all=true
        fi
        ;;
      examples/root-plan-harness/* | examples/root-plan-harness | \
      backend.tf | data.tf | main.tf | outputs.tf | terraform.tfvars | variables.tf | \
      environments/* | \
      tests/root-plan.tftest.hcl | \
      templates/* | scripts/azure-pipelines/* | scripts/terraform-change-summary.sh)
        run_all=true
        ;;
      examples/*)
        local example_name="${changed_file#examples/}"
        example_name="${example_name%%/*}"
        if is_known_module "${example_name}"; then
          selected["${example_name}"]=1
        fi
        ;;
    esac
  done

  if [[ "${run_all}" == "true" ]]; then
    printf '%s\n' "${MODULES[@]}"
    return
  fi

  declare -A expanded=()
  local module_name
  for module_name in "${!selected[@]}"; do
    while IFS= read -r related_module; do
      [[ -z "${related_module}" ]] && continue
      expanded["${related_module}"]=1
    done < <(expand_related_modules "${module_name}")
  done

  for module_name in "${MODULES[@]}"; do
    if [[ -n "${expanded[$module_name]:-}" ]]; then
      printf '%s\n' "${module_name}"
    fi
  done
}

select_changed_modules() {
  local base_ref="$1"
  local head_ref="$2"
  local normalized_base
  normalized_base="$(normalize_base_ref "${base_ref}" "${head_ref}")"

  git diff --name-only "${normalized_base}" "${head_ref}" | select_modules_from_changed_files
}

select_modules_from_file() {
  local input_file="$1"
  cat "${input_file}" | select_modules_from_changed_files
}

write_overrides_file() {
  local target_module="$1"
  local output_file="$2"

  if ! is_known_module "${target_module}"; then
    echo "Unknown module: ${target_module}" >&2
    exit 1
  fi

  declare -A enabled=()
  local module_name
  while IFS= read -r module_name; do
    [[ -z "${module_name}" ]] && continue
    enabled["${module_name}"]=1
  done < <(expand_related_modules "${target_module}")

  {
    echo "{"
    echo '  "features": {},'
    echo '  "module_plan_enabled": {'
    for i in "${!MODULES[@]}"; do
      module_name="${MODULES[$i]}"
      local suffix=","
      if [[ "${i}" -eq $((${#MODULES[@]} - 1)) ]]; then
        suffix=""
      fi

      if [[ -n "${enabled[$module_name]:-}" ]]; then
        echo "    \"${module_name}\": true${suffix}"
      else
        echo "    \"${module_name}\": false${suffix}"
      fi
    done
    echo "  }"
    echo "}"
  } > "${output_file}"
}

print_json_array() {
  local values=("$@")
  printf '['
  local first=true
  local value
  for value in "${values[@]}"; do
    if [[ "${first}" == "true" ]]; then
      first=false
    else
      printf ','
    fi
    printf '"%s"' "${value}"
  done
  printf ']'
}

print_github_matrix() {
  local values=("$@")
  printf '{"module":'
  print_json_array "${values[@]}"
  printf '}'
}

print_ado_matrix() {
  local values=("$@")
  printf '{'
  local first=true
  local value
  for value in "${values[@]}"; do
    if [[ "${first}" == "true" ]]; then
      first=false
    else
      printf ','
    fi
    printf '"%s":{"moduleName":"%s"}' "${value}" "${value}"
  done
  printf '}'
}

usage() {
  cat <<'EOF'
Usage:
  scripts/azure-pipelines/module-harness-targets.sh detect --base <ref> --head <ref> --format <github-matrix|ado-matrix|json-array|newline>
  scripts/azure-pipelines/module-harness-targets.sh detect-files --input <path> --format <github-matrix|ado-matrix|json-array|newline>
  scripts/azure-pipelines/module-harness-targets.sh overrides --module <name> --output <path>
EOF
}

command="${1:-}"
shift || true

case "${command}" in
  detect)
    base_ref=""
    head_ref=""
    format=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --base)
          base_ref="${2:-}"
          shift 2
          ;;
        --head)
          head_ref="${2:-}"
          shift 2
          ;;
        --format)
          format="${2:-}"
          shift 2
          ;;
        *)
          echo "Unknown argument: $1" >&2
          usage
          exit 1
          ;;
      esac
    done

    if [[ -z "${head_ref}" || -z "${format}" ]]; then
      usage
      exit 1
    fi

    if ! git rev-parse --verify "${head_ref}^{commit}" >/dev/null 2>&1; then
      echo "Unable to resolve head ref: ${head_ref}" >&2
      exit 1
    fi

    mapfile -t modules < <(select_changed_modules "${base_ref}" "${head_ref}")

    case "${format}" in
      github-matrix)
        print_github_matrix "${modules[@]}"
        ;;
      ado-matrix)
        print_ado_matrix "${modules[@]}"
        ;;
      json-array)
        print_json_array "${modules[@]}"
        ;;
      newline)
        printf '%s\n' "${modules[@]}"
        ;;
      *)
        echo "Unknown format: ${format}" >&2
        exit 1
        ;;
    esac
    ;;
  detect-files)
    input_file=""
    format=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --input)
          input_file="${2:-}"
          shift 2
          ;;
        --format)
          format="${2:-}"
          shift 2
          ;;
        *)
          echo "Unknown argument: $1" >&2
          usage
          exit 1
          ;;
      esac
    done

    if [[ -z "${input_file}" || -z "${format}" ]]; then
      usage
      exit 1
    fi

    if [[ ! -f "${input_file}" ]]; then
      echo "Input file does not exist: ${input_file}" >&2
      exit 1
    fi

    mapfile -t modules < <(select_modules_from_file "${input_file}")

    case "${format}" in
      github-matrix)
        print_github_matrix "${modules[@]}"
        ;;
      ado-matrix)
        print_ado_matrix "${modules[@]}"
        ;;
      json-array)
        print_json_array "${modules[@]}"
        ;;
      newline)
        printf '%s\n' "${modules[@]}"
        ;;
      *)
        echo "Unknown format: ${format}" >&2
        exit 1
        ;;
    esac
    ;;
  overrides)
    target_module=""
    output_file=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --module)
          target_module="${2:-}"
          shift 2
          ;;
        --output)
          output_file="${2:-}"
          shift 2
          ;;
        *)
          echo "Unknown argument: $1" >&2
          usage
          exit 1
          ;;
      esac
    done

    if [[ -z "${target_module}" || -z "${output_file}" ]]; then
      usage
      exit 1
    fi

    write_overrides_file "${target_module}" "${output_file}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
