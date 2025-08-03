# FlashAir-to-SleepHQ
Syncs new CPAP data from FlashAir to local Dropbox folder, creates ZIP, uploads to SleepHQ if sleep data present.

Based on sync.sh from https://github.com/iitggithub/ezshare_cpap, licensed under MIT

The purpose of this repository is to automatically retrieve ResMed CPAP sleep data from a Toshiba FlashAir W-04 WiFi SD card installed in a ResMed AirSense 10 CPAP, save it to ~/DropBox/ResMed Sleep Data, compress it, and then upload it to SleepHQ.com via the API.

# Requirements:
- ResMed CPAP machine (Tested with AirSense 10, but should work with others)
- SleepHQ.com Paid account required for API access to support auto sync
  - If you just want to automatically download the sleep data from the FlashAir SD and don't mind manually uploading via the SleepHQ Data Imports screen, then you do not need a paid account.



Flowchart: Automation Components for CPAP Data Sync
```
+-------------------------------------+
| com.user.pollflashair.plist         |
| Purpose: launchd configurtion file |
| to schedule and run poll_flashair.sh|
| automatically on macOS. Loads at    |
| startup and runs every 30 minutes.  |
| No direct input/output; manages     |
| execution of poll_flashair.sh.      |
+-------------------------------------+
                   |
                   | (Loads and schedules)
                   v
+-------------------------------------+
| poll_flashair.sh                    |
| Purpose: Polls FlashAir card for new|
| complete sleep data in DATALOG      |
| folders (checks for 10 expected     |
| files unmodified for >1 hour). If   |
| detected, triggers sync.sh. Runs    |
| every 30 min via launchd.           |
| Input: FlashAir URL, last poll time |
| Output: Triggers sync.sh if new data|
+-------------------------------------+
                   |
                   | (If new complete data found)
                   v
+-------------------------------------+
| sync.sh                             |
| Purpose: Syncs new CPAP data from   |
| FlashAir to local Dropbox folder,   |
| creates ZIP, uploads to SleepHQ if  |
| sleep data present. Manual or auto- |
| triggered by poll_flashair.sh.      |
| Input: FlashAir data, credentials   |
| Output: Local files, SleepHQ upload |
+-------------------------------------+
```
Timing and Order:
- launchd (plist) starts at system boot and runs poll_flashair.sh every 30 minutes.
- poll_flashair.sh checks for new data; if yes, runs sync.sh immediately.
- sync.sh executes the sync and upload (runs in ~5-10 seconds typically).
- Cycle repeats every 30 min; no user input needed after setup.

# Directory Structure
~/Library/LaunchAgents/com.user.pollflashair.plist
~/Documents/ResMed Automation/poll_flashair.sh
~/Documents/ResMed Automation/sync.sh
~/Dropbox/ResMed CPAP Data
* Dropbox is not required, you can store your sleep data wherever you wish.
