
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

log_output() {

  level="${1}"
  message="${2}"

  echo -e $(date +"[%Y-%m-%d %H:%M:%S %z] ${level}  ${message}")
}

log_info() {
  message="${1}"
  log_output "    " "${message}"
}

log_warn() {
  message="${1}"
  log_output " [${BOLD}WARNING${NC}]" "${message}"
}

log_error() {
  message="${1}"
  log_output " [${BOLD}${RED}ERROR${NC}]" "${message}"
}

