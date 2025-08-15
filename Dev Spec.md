# FlashAir-to-SleepHQ Developer Specification

This document provides a high-level overview of the FlashAir-to-SleepHQ project's features, file structure, logical flow, and key validations/logical tests. The project automates syncing CPAP sleep data from a Toshiba FlashAir Wi-Fi SD card to a local directory and optionally to SleepHQ, with macOS launchd integration for scheduling. It emphasizes reliability through connectivity checks, error handling, and user-configurable options. Designed for simplicity, the system uses bash scripts for portability across macOS and Linux.

## Project Overview
- **Purpose**: Automate extraction of sleep data from FlashAir SD card in ResMed CPAP machines, sync locally, and upload to SleepHQ for analysis.
- **Core Workflow**: Scheduled polling triggers sync, which handles Wi-Fi switching, data download, and API upload.
- **Key Technologies**: Bash scripting, curl for HTTP, launchd for macOS automation, macOS keychain/Linux files for credential storage.
- **Assumptions**: FlashAir card configured with static IP (192.168.1.50), user has Wi-Fi access to both home and card networks, optional SleepHQ API credentials.

## File Structure and Descriptions
- **sync.sh**: Core script for data sync and upload. Features Wi-Fi connection handling, file download from SD card, zip creation, and SleepHQ API integration.
- **poll_flashair.sh**: Wrapper for `sync.sh`. Handles dynamic path resolution, execution checks, and logging to daily files in `logs/` dir with configurable retention.
- **com.user.pollflashair.plist.template**: macOS launchd template for scheduling `poll_flashair.sh`. Customizable with user paths for script and logs.
- **FlashAir Config.md**: Guide for FlashAir SD card CONFIG file setup (e.g., IP, Wi-Fi mode, SSID/password).
- **flowchart.png**: Visual representation of system workflow.
- **LICENSE**: MIT License file for distribution and usage terms.
- **README.md**: User-facing setup instructions, overview, and troubleshooting.

## Features
- **Data Sync**: Downloads new/updated files from FlashAir SD card DATALOG directory to local `sdCardDir`, using timestamp and size comparisons.
- **Wi-Fi Management**: Switches between home and FlashAir Wi-Fi networks if single adaptor; verifies connectivity before operations.
- **SleepHQ Upload**: Optional zip creation and API upload of synced data, with access token generation, import task creation, file upload, and progress monitoring.
- **Automation**: launchd schedules hourly runs via `poll_flashair.sh`, which executes `sync.sh`.
- **Logging**: Daily logs in `logs/` dir with configurable retention (default 30 days); timestamps on all entries.
- **Error Handling**: Checks for script executability, file existence, API failures, and connectivity; logs errors with exit codes.
- **Configurability**: Variables for retention, URLs, upload enablement; command-line flags (e.g., `--full-sync`, `--skip-upload`).

## Logical Flow
- **Initialization**: launchd triggers `poll_flashair.sh` on schedule/login.
- **Wrapper Execution** (`poll_flashair.sh`):
  - Resolve paths and verify `sync.sh`.
  - Log start timestamp.
  - Run `sync.sh`, redirecting output/errors.
  - Log success/failure.
  - Truncate old logs if retention >0.
- **Sync Process** (`sync.sh`):
  - Load configs/credentials.
  - Switch to home Wi-Fi if needed.
  - Check last sync timestamp.
  - Switch to FlashAir Wi-Fi.
  - Verify FlashAir connectivity.
  - Scan directories/files for changes.
  - Download new files if found.
  - Switch back to home Wi-Fi.
  - If new sleep data, zip and upload to SleepHQ (with API validation).
  - Update sync timestamp.
- **Error Paths**: Failures (e.g., connectivity) exit early, log errors, and clean up (e.g., Wi-Fi revert).
- **Manual Run**: Users can bypass automation by running `sync.sh` directly.

## Validations and Logical Tests
- **Wi-Fi Connectivity**: Pre-sync check to home/FlashAir networks; retry 5-15 times; fail and revert Wi-Fi if unreachable.
- **File/Directory Existence**: Verify `sdCardDir`, transfer logs, zip files; create if missing.
- **Script Executability**: Check/ fix permissions on `sync.sh` before running.
- **Timestamp Comparison**: Compare file timestamps vs. last sync to detect new/changed data; fallback to filename parsing if API timestamps fail.
- **File Size Validation**: Compare local/remote sizes to detect changes, with rounding for SD card inaccuracies.
- **API Credential Validation**: Prompt and test SleepHQ credentials on first run; fail upload if token generation fails.
- **Data Completeness**: Ensure downloaded files are present before zipping/uploading; skip if no sleep data.
- **Error/Exit Handling**: Trap signals for cleanup; log exit codes; rollback partial syncs.
- **Retention Check**: Post-run, delete log files older than configured days if enabled.
- **Edge Case Tests**: Handle empty logs, non-numeric timestamps (assume new), multiple adaptors (no switching needed).
