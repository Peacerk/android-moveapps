# MoveApps.ps1

A PowerShell script to manage and move Android apps between internal and adopted (SD card) storage using ADB.

## Features
- Connects to your Android device via ADB
- Detects device model and adopted storage UUID
- Lists all user-installed apps on internal and adopted storage with numbering
- Lets you select apps to move by number (supports multiple selections)
- For each selected app:
  - Shows app size and available space on the target storage
  - Asks for confirmation before moving
  - Moves the app if there is enough space
  - Skips or cancels if not enough space or on user request
- Provides clear feedback and error handling throughout

## Requirements
- Windows with PowerShell 7+
- [Android Platform Tools (ADB)](https://developer.android.com/tools/releases/platform-tools) installed and added to your system PATH
- An Android device with USB debugging enabled
- Adopted storage (SD card formatted as internal) if you want to move apps to/from SD card

## Usage
1. **Connect your Android device** via USB and enable USB debugging.
2. **Open PowerShell** and navigate to the folder containing `MoveApps.ps1`.
3. **Run the script:**
   ```powershell
   .\MoveApps.ps1
   ```
4. **Follow the prompts:**
   - The script will show your device model and adopted storage UUID (if present).
   - It will list all apps on internal and adopted storage, each with a number.
   - Enter the numbers of the apps you want to move, separated by commas (e.g., `2,11,15`).
   - For each app, the script will show the app size and available space on the target storage, and ask for confirmation before moving.
   - The script will move the app if there is enough space, or skip/cancel as appropriate.

## Example
```
Enter the numbers of apps to move (separated by commas):
2,11
📂 com.example.app App size: 45 MB, Destination (ADOPTED storage) available size: 1200 MB
Do you want to Move com.example.app from INTERNAL storage to ADOPTED storage ? (type y to continue)
Moving com.example.app from INTERNAL storage >>>>> ADOPTED storage ...
Moved Successfully !
```

## Notes
- The script only lists and moves apps installed in `/data/app` (internal) and `/mnt/expand/<UUID>` (adopted) storage.
- System apps and apps in other locations are not shown.
- Moving apps requires Android 6.0+ and may not work for all apps or all devices.
- The script checks available space and app size before moving, but actual move success depends on device/ROM support.
- You may need to grant ADB permissions on your device when prompted.

## Troubleshooting
- If ADB is not found, ensure it is installed and added to your system PATH.
- If your device is not detected, check USB connection and that USB debugging is enabled.
- If you see permission errors, try running PowerShell as Administrator.

## License
MIT 
