#!/bin/bash
# Path to sync.sh (adjust if different)
SYNC_SCRIPT="$(dirname "$0")/sync.sh"
# FlashAir URL
FLASH_AIR_URL="http://192.168.1.50"
# Last poll timestamp file (global, for initial folder filtering)
LAST_POLL_FILE="$(dirname "$0")/.last_poll_time"
# Per-folder state file
STATE_FILE="$HOME/.flashair_folder_state"
# Days to check back for recent folders
DAYS_TO_CHECK=3
# Required types (always expected for complete session; edf + crc per segment)
REQUIRED_TYPES=("BRP" "EVE" "PLD")
# Optional types (e.g., CSL if CSR detected, SAD if oximeter connected)
OPTIONAL_TYPES=("CSL" "SAD")
# Combined for indexing
ALL_TYPES=("${REQUIRED_TYPES[@]}" "${OPTIONAL_TYPES[@]}")
# Stale threshold (seconds, e.g., 24 hours)
STALE_THRESHOLD=86400
# Function to get current Unix timestamp
get_current_time() {
date +%s
}
# Function to get directory listing from FlashAir (CSV format)
get_listing() {
local path="$1"
curl -s --connect-timeout 5 --max-time 10 "${FLASH_AIR_URL}/command.cgi?op=100&DIR=${path}"
}
# Function to parse timestamp from has/time (FlashAir format)
parse_timestamp() {
local has="$1"
local time="$2"
local fallback_name="$3"  # Optional: file or folder name for fallback parsing
local timestamp=0

# First, try API has/time
if [[ $has =~ ^[0-9]+$ ]] && [[ $time =~ ^[0-9]+$ ]]; then
  year=$(( (time >> 9) + 1980 ))
  month=$(( (time >> 5) & 15 ))
  day=$(( time & 31 ))
  hour=$(( (has >> 11) & 31 ))
  minute=$(( (has >> 5) & 63 ))
  second=$(( (has & 31) * 2 ))
  timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "$(printf "%d-%02d-%02d %02d:%02d:%02d" $year $month $day $hour $minute $second)" +%s 2>/dev/null || echo 0)
fi

# If API failed (timestamp=0) and fallback_name provided, parse from name
if [ "${timestamp}" -eq 0 ] && [ -n "${fallback_name}" ]; then
  if [[ "${fallback_name}" =~ ^([0-9]{8})_([0-9]{6})_ ]]; then  # File format: YYYYMMDD_HHMMSS_TYPE.edf|crc
    date_str="${BASH_REMATCH[1]:0:4}-${BASH_REMATCH[1]:4:2}-${BASH_REMATCH[1]:6:2} ${BASH_REMATCH[2]:0:2}:${BASH_REMATCH[2]:2:2}:${BASH_REMATCH[2]:4:2}"
    timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "${date_str}" +%s 2>/dev/null || echo 0)
  elif [[ "${fallback_name}" =~ ^[0-9]{8}$ ]]; then  # Folder format: YYYYMMDD (assume end of day for polling purposes)
    date_str="${fallback_name:0:4}-${fallback_name:4:2}-${fallback_name:6:2} 23:59:59"
    timestamp=$(date -j -f "%Y-%m-%d %H:%M:%S" "${date_str}" +%s 2>/dev/null || echo 0)
  fi
fi

echo "${timestamp}"
}
# Load per-folder state (simple key-value, folder:count|max_time|last_check|last_sync)
load_state() {
local folder="$1"
if [ -f "${STATE_FILE}" ]; then
  line=$(grep "^${folder}:" "${STATE_FILE}" | cut -d ':' -f2-)
  if [ -n "${line}" ]; then
    echo "${line}" | tr '|' ' '
    return
  fi
fi
echo "0 0 0 0"
}
# Save per-folder state
save_state() {
local folder="$1"
local count="$2"
local max_time="$3"
local check_time="$4"
local sync_time="$5"
# Remove old line if exists
sed -i.bak "/^${folder}:/d" "${STATE_FILE}" 2>/dev/null
echo "${folder}:${count}|${max_time}|${check_time}|${sync_time}" >> "${STATE_FILE}"
rm -f "${STATE_FILE}.bak"
}
# Get last poll time or 0 if not set
last_poll=$(cat "${LAST_POLL_FILE}" 2>/dev/null || echo 0)
current_time=$(get_current_time)
echo "Starting poll_flashair.sh... (Current time: ${current_time})"
# List DATALOG folders
datalog_csv=$(get_listing "/DATALOG")
new_data=false
success=false
# Debug: Show if DATALOG listing succeeded
if [ -z "${datalog_csv}" ]; then
  echo "Debug: Failed to get DATALOG listing (card not accessible?)."
else
  echo "Debug: DATALOG listing fetched successfully."
  success=true
  # Calculate earliest date to check (e.g., today - DAYS_TO_CHECK)
  earliest_date=$(date -j -v-"${DAYS_TO_CHECK}"d +%Y%m%d)
  # Process folders (use process substitution to avoid subshell)
  while IFS=',' read -r dir name size attr has time; do
    if (( (attr & 16) == 16 )) && [[ "${name}" =~ ^[0-9]{8}$ ]] && [ "${name}" -ge "${earliest_date}" ]; then # Recent DATALOG/YYYYMMDD dir
      folder_time=$(parse_timestamp "${has}" "${time}" "${name}")
      echo "Debug: Found recent folder ${name}, timestamp: ${folder_time} (human: $(date -r "${folder_time}" 2>/dev/null || echo "invalid"))"
      # Load previous state
      read -r prev_count prev_max_time prev_check prev_sync < <(load_state "${name}")
      prev_count=${prev_count:-0}
      prev_max_time=${prev_max_time:-0}
      prev_check=${prev_check:-0}
      prev_sync=${prev_sync:-0}
      echo "Debug: Loaded state for ${name} - prev_count: ${prev_count}, prev_max_time: ${prev_max_time}, prev_check: ${prev_check}, prev_sync: ${prev_sync}"
      echo "Debug: Checking folder ${name} for changes/completeness."
      # Get current files
      folder_csv=$(get_listing "/DATALOG/${name}")
      file_count=0
      max_file_time=0
      detected_types=""
      required_detected=true
      type_counts=(0 0 0 0 0) # Indices: 0=BRP, 1=EVE, 2=PLD, 3=CSL, 4=SAD
      # Process files
      while IFS=',' read -r f_dir f_name f_size f_attr f_has f_time; do
        echo "Debug: Found file in folder: ${f_name}"
        if (( (f_attr & 16) == 0 )); then # File
          matched=false
          for i in 0 1 2 3 4; do
            typ=${ALL_TYPES[$i]}
            if [[ "${f_name}" = *_"${typ}.edf" ]] || [[ "${f_name}" = *_"${typ}.crc" ]]; then
              echo "Debug: Matched expected file: ${f_name} (type: ${typ})"
              ((file_count++))
              f_time=$(parse_timestamp "${f_has}" "${f_time}" "${f_name}")
              echo "Debug: File ${f_name} timestamp: ${f_time} (human: $(date -r "${f_time}" 2>/dev/null || echo "invalid"))"
              if [ "${f_time}" -gt "${max_file_time}" ]; then
                max_file_time="${f_time}"
              fi
              ((type_counts[i]++))
              if ! echo "${detected_types}" | grep -q "${typ}"; then
                detected_types="${detected_types}${typ} "
              fi
              matched=true
              break
            fi
          done
          if ! $matched; then
            echo "Debug: Unmatched file: ${f_name} (ignoring for count)"
          fi
        fi
      done < <(echo "${folder_csv}" | tail -n +2)
      # Trim trailing space
      detected_types="${detected_types% }"
      # Check if all required types are present
      for req in "${REQUIRED_TYPES[@]}"; do
        if ! echo "${detected_types}" | grep -q "${req}"; then
          required_detected=false
          echo "Debug: Missing required type: ${req}"
        fi
      done
      echo "Debug: After processing files - file_count: ${file_count}, detected_types: ${detected_types}, max_file_time: ${max_file_time} (human: $(date -r "${max_file_time}" 2>/dev/null || echo "invalid"))"
      echo "Debug: Folder ${name} has ${file_count} matched files, max file time: ${max_file_time} (age: $((current_time - max_file_time)) seconds)."
      # Detect change or stale
      has_changed=false
      if [ "${file_count}" -gt "${prev_count}" ] || [ "${max_file_time}" -gt "${prev_max_time}" ] || [ $((current_time - prev_check)) -gt "${STALE_THRESHOLD}" ]; then
        has_changed=true
        echo "Debug: Changes or stale state detected in ${name}."
      fi
      # Trigger if changed/stale, required present, file_count even, >=6, age >1 hour
      if ${has_changed} && ${required_detected} && (( file_count % 2 == 0 )) && [ "${file_count}" -ge 6 ] && [ $((current_time - max_file_time)) -gt 3600 ]; then
        new_data=true
        echo "Debug: New/changed/stale complete data detected in ${name}."
      fi
      # Update state only if no trigger (on trigger, update after sync in exitFunction or manually); for no-trigger, update to avoid loops
      if ! ${new_data}; then
        save_state "${name}" "${file_count}" "${max_file_time}" "${current_time}" "${prev_sync}"
        echo "Debug: Updated state for ${name} (no trigger)."
      fi
    fi
  done < <(echo "${datalog_csv}" | tail -n +2)
fi
if ${new_data}; then
  echo "Debug: Triggering sync.sh"
  # Run sync.sh
  bash "${SYNC_SCRIPT}"
  # Update state after successful sync (assume sync succeeds; if not, manual reset)
  # Note: To make this more robust, you could add logic in sync.sh to signal success, but for now, update here
  save_state "${name}" "${file_count}" "${max_file_time}" "${current_time}" "${current_time}"
  echo "Debug: Updated state after sync for ${name}."
fi
# Only update global last poll time after a successful poll
if ${success}; then
  echo "${current_time}" > "${LAST_POLL_FILE}"
  echo "Debug: Poll completed, last poll time updated to ${current_time}."
else
  echo "Debug: Poll failed (no listing), not updating last poll time to allow retry."
fi
