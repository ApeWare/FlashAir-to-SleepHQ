#!/bin/bash

# Path to sync.sh (adjust if different)
SYNC_SCRIPT="$(dirname "$0")/sync.sh"

# FlashAir URL
FLASH_AIR_URL="http://192.168.1.50"

# Last poll timestamp file
LAST_POLL_FILE="$(dirname "$0")/.last_poll_time"

# Expected files in a DATALOG folder for complete data
EXPECTED_FILES=("BRP.edf" "CSL.edf" "EVE.edf" "PLD.edf" "SAD.edf" "BRP.edf.crc" "CSL.edf.crc" "EVE.edf.crc" "PLD.edf.crc" "SAD.edf.crc")

# Function to get current Unix timestamp
get_current_time() {
  date +%s
}

# Function to get directory listing from FlashAir (CSV format)
get_listing() {
  local path="$1"
  curl -s "${FLASH_AIR_URL}/command.cgi?op=100&DIR=${path}"
}

# Function to parse timestamp from has/time (FlashAir format)
parse_timestamp() {
  local has="$1"
  local time="$2"
  if ! [[ $has =~ ^[0-9]+$ ]] || ! [[ $time =~ ^[0-9]+$ ]]; then
    echo 0
    return
  fi
  year=$(( (time >> 9) + 1980 ))
  month=$(( (time >> 5) & 15 ))
  day=$(( time & 31 ))
  hour=$(( (has >> 11) & 31 ))
  minute=$(( (has >> 5) & 63 ))
  second=$(( (has & 31) * 2 ))
  date -j -f "%Y-%m-%d %H:%M:%S" "$(printf "%d-%02d-%02d %02d:%02d:%02d" $year $month $day $hour $minute $second)" +%s 2>/dev/null || echo 0
}

# Get last poll time or 0 if not set
last_poll=$(cat "${LAST_POLL_FILE}" 2>/dev/null || echo 0)

current_time=$(get_current_time)

# List DATALOG folders
datalog_csv=$(get_listing "/DATALOG")
new_data=false

	# Skip header, loop for dirs
	echo "${datalog_csv}" | tail -n +2 | while IFS=',' read -r dir name size attr has time; do
	  if (( (attr & 16) == 16 )) && [[ "${name}" =~ ^[0-9]{8}$ ]]; then  # DATALOG/YYYYMMDD dir
	    folder_time=$(parse_timestamp "${has}" "${time}")
	    if [ -n "${folder_time}" ] && [ "${folder_time}" -gt "${last_poll}" ]; then
	      # Check if complete
	      folder_csv=$(get_listing "/DATALOG/${name}")
	      file_count=0
	      max_file_time=0
	      echo "${folder_csv}" | tail -n +2 | while IFS=',' read -r f_dir f_name f_size f_attr f_has f_time; do
	        if (( (f_attr & 16) == 0 )) && printf '%s\n' "${EXPECTED_FILES[@]}" | grep -q "^${f_name}$"; then
	          ((file_count++))
	          f_time=$(parse_timestamp "${f_has}" "${f_time}")
	          if [ "${f_time}" -gt "${max_file_time}" ]; then
	            max_file_time="${f_time}"
	          fi
	        fi
	      done
	      if [ "${file_count}" -eq 10 ] && [ $((current_time - max_file_time)) -gt 3600 ]; then  # 10 files, no changes in 1 hour
	        new_data=true
	      fi
	    fi
	  fi
	done

if ${new_data}; then
  # Run sync.sh
  bash "${SYNC_SCRIPT}"
  # Update last poll time
  echo "${current_time}" > "${LAST_POLL_FILE}"
fi
