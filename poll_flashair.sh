#!/bin/bash
# Wrapper script to run sync.sh for FlashAir-to-SleepHQ automation
# Logs output and errors, ensures sync.sh is found and executable

# Determine the directory of this script for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/sync.sh"

# Log file paths (should match the plist template's <PATH_TO_LOGS>)
LOG_DIR="${SCRIPT_DIR}"
STARTUP_LOG="${LOG_DIR}/sync-startup-log.txt"
ERROR_LOG="${LOG_DIR}/sync-error-log.txt"

# Check if sync.sh exists and is executable
if [ ! -f "${SYNC_SCRIPT}" ]; then
  echo "Error: sync.sh not found at ${SYNC_SCRIPT}. Please ensure it's in the same directory." >&2
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: sync.sh not found" >> "${ERROR_LOG}"
  exit 1
fi

if [ ! -x "${SYNC_SCRIPT}" ]; then
  echo "Error: sync.sh is not executable at ${SYNC_SCRIPT}. Fixing permissions..." >&2
  chmod +x "${SYNC_SCRIPT}"
  if [ ! -x "${SYNC_SCRIPT}" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Failed to make sync.sh executable" >> "${ERROR_LOG}"
    exit 1
  fi
fi

# Log start time
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting synchronization" >> "${STARTUP_LOG}"

# Execute sync.sh with output redirection
"${SYNC_SCRIPT}" >> "${STARTUP_LOG}" 2>> "${ERROR_LOG}"

# Log completion or check exit status
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Synchronization completed successfully" >> "${STARTUP_LOG}"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Synchronization failed with exit code ${EXIT_CODE} (see error log)" >> "${ERROR_LOG}"
fi

exit ${EXIT_CODE}
