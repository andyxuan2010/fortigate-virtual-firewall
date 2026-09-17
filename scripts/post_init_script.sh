#!/bin/bash
set -euo pipefail

LOG_DIR="/var/log/localization"
LOG_FILE="${LOG_DIR}/post-init.log"

mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"
chmod 0600 "${LOG_FILE}" || true
exec >>"${LOG_FILE}" 2>&1

log() {
  printf '[%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

apt_is_busy() {
  if command -v fuser >/dev/null 2>&1; then
    fuser /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock >/dev/null 2>&1
    return $?
  fi

  pgrep -x apt >/dev/null 2>&1 || \
  pgrep -x apt-get >/dev/null 2>&1 || \
  pgrep -x dpkg >/dev/null 2>&1 || \
  pgrep -f unattended-upgrade >/dev/null 2>&1
}

wait_for_apt() {
  local waited=0
  local timeout=240
  local interval=5

  while apt_is_busy; do
    if [ "${waited}" -ge "${timeout}" ]; then
      log "Timed out after ${timeout}s waiting for apt/dpkg to become available"
      return 1
    fi

    log "Another apt/dpkg process is running; waiting ${interval}s (${waited}/${timeout}s)"
    sleep "${interval}"
    waited=$((waited + interval))
  done

  log "apt/dpkg is available"
}

apt_update_safe() {
  wait_for_apt
  log "Running apt-get update"
  apt-get update -y
}

apt_install_safe() {
  wait_for_apt
  log "Installing packages: $*"
  apt-get install -y "$@"
}

trap 'rc=$?; log "ERROR: script failed at line ${LINENO} with exit code ${rc}"; exit ${rc}' ERR

log "custom post-init script started"
export DEBIAN_FRONTEND=noninteractive
mkdir -p /opt/bootstrap
touch /opt/bootstrap/post-init-ran
cat /etc/os-release

apt_update_safe

timedatectl set-timezone America/Toronto || true
