This config is tailored for your Toshiba FlashAir card to sync data with SleepHQ. Here’s the key configuration details:

- **IP Address**: The FlashAir card should be configured with a static IP of `192.168.1.50`. This is set in the `flashAirURL="http://192.168.1.50/"` variable in the "GLOBAL VARIABLES" section of `sync.sh`. To configure this:
  1. Insert the FlashAir card into a computer.
  2. Open the `CONFIG` file on the card (e.g., using a text editor).
  3. Ensure the following line is present or add/update it:
     ```
     IPADDRESS=192.168.1.50
     ```
  4. Save the file and eject the card. This IP should match your local network’s subnet (e.g., 192.168.1.x) and avoid conflicts with other devices.

- **Wi-Fi Settings**: The card needs to be accessible via a Wi-Fi network. During the first run of `sync.sh`, you’ll be prompted to enter the FlashAir Wi-Fi SSID (e.g., "ResMed_FlashAir") and password. These are stored securely:
  - On macOS, in the keychain under "flashAir" service.
  - On Linux, in `~/.flashair` config files.
  - To set the SSID and password initially, edit the `CONFIG` file and add or update:
    ```
    APPAUTH=1  # Enable authentication
    APPAUTHKEY=your_password_here  # Set a password
    APPAUTHTIMEOUT=300  # Optional: Set timeout in seconds
    ```
    Replace `your_password_here` with a secure password, then run `sync.sh` to input the SSID.

- **Directory Structure**: The script expects the FlashAir card to have a standard directory layout (e.g., `/DCIM`, `/DATALOG`, `/SETTINGS`). No changes are needed here unless your card uses a custom structure, in which case update the `dirList=("/")` array in `sync.sh` to reflect the root directories to scan.

- **Sync Settings**: In `sync.sh`, the following variables control behavior:
  - `sdCardDir="/Users/$(whoami)/Desktop/SD_Card"` (macOS default; adjust to your preferred local folder).
  - `maxParallelDirChecks=15` and `maxParallelDownloads=5` (tune these for performance if needed).
  - `sleepHQuploadsEnabled=false` (set to `true` to enable SleepHQ uploads; requires API credentials).

- **API Integration (Optional)**: For SleepHQ uploads, configure API credentials during the first `sync.sh` run. These include Client UID, Client Secret, and Device ID, stored securely as above.

### Verification
- After updating the `CONFIG` file, insert the card into your device and connect to its Wi-Fi network. Use a browser to visit `http://192.168.1.50/`—you should see the FlashAir web interface.
- Run `./sync.sh` from the repository directory to test connectivity and sync. Check logs (`sync-startup-log.txt`, `sync-error-log.txt`) if issues arise.

This configuration ensures the FlashAir card integrates with the script for automated data syncing. 
