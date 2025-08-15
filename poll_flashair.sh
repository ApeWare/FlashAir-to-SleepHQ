#!/bin/bash
# Wrapper script to run sync.sh for FlashAir-to-SleepHQ automation
# Logs output and errors to daily files in logs/ dir, with configurable retention

# Determine the directory of this script for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC_SCRIPT="${SCRIPT_DIR}/sync.sh"

# Configurable retention (days): -1 = no logging, 0 = infinite, >0 = delete files older than N days
LOG_RETENTION_DAYS=30

# Log directory and daily log files
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "${LOG_DIR}"  # Create logs dir if not exists

# If no logging, exit early after running sync.sh
if [ "${LOG_RETENTION_DAYS}" -eq -1 ]; then
  "${SYNC_SCRIPT}"
  exit $?
fi

# Daily log files
DATE_STAMP=$(date '+%Y%m%d')
STARTUP_LOG="${LOG_DIR}/${DATE_STAMP}-startup.log"
ERROR_LOG="${LOG_DIR}/${DATE_STAMP}-error.log"

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

# Log start time (append to today's file)
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting synchronization" >> "${STARTUP_LOG}"

# Execute sync.sh with output redirection (append)
"${SYNC_SCRIPT}" >> "${STARTUP_LOG}" 2>> "${ERROR_LOG}"

# Log completion or check exit status
EXIT_CODE=$?
if [ ${EXIT_CODE} -eq 0 ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Synchronization completed successfully" >> "${STARTUP_LOG}"
else
  echo "$(date '+%Y-%m-%d %H:%M:%S') - Synchronization failed with exit code ${EXIT_CODE} (see error log)" >> "${ERROR_LOG}"
fi

# If retention >0, delete old log files (both -startup.log and -error.log)
if [ "${LOG_RETENTION_DAYS}" -gt 0 ]; then
  find "${LOG_DIR}" -type f -name "*-startup.log" -mtime +${LOG_RETENTION_DAYS} -delete
  find "${LOG_DIR}" -type f -name "*-error.log" -mtime +${LOG_RETENTION_DAYS} -delete
fi

exit ${EXIT_CODE}
