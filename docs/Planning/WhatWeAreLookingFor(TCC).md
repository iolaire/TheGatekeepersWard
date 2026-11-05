## What to look for:
2. Protected TCC Services to Filter For
	AI coding agents typically trip over file-system boundaries or automation capabilities. The sniffer checks the [service] token in the log message for these key identifiers:
	File System Scopes (Common with find, grep, git, or model scrapers):
	kTCCServiceSystemPolicyDocumentsFolder (~/Documents)
	kTCCServiceSystemPolicyDesktopFolder (~/Desktop)
	kTCCServiceSystemPolicyDownloadsFolder (~/Downloads)
	kTCCServiceSystemPolicyNetworkVolumes / kTCCServiceSystemPolicyRemovableVolumes
	Personal Data & Automation Scopes (Accidental shell or system queries):
	kTCCServiceAddressBook (Contacts)
	kTCCServiceCalendar / kTCCServiceReminders
	kTCCServiceAppleEvents (Scripting/controlling other apps via AppleScript/OSA)


## Full list (ai):
Apple does not publish an official header or documentation page enumerating all TCC strings. Instead, these constants are compiled directly into the system daemon (`/System/Library/PrivateFrameworks/TCC.framework/Support/tccd`) and the `TCC.framework` private framework.

Security researchers extract the complete canonical list directly from the `tccd` binary. The system keys break down into two main families: the **`kTCCServiceSystemPolicy*`** keys (which control filesystem access) and the general **`kTCCService*`** capability and sensor keys.

---

### 1. The `kTCCServiceSystemPolicy*` Keys (Filesystem Scopes)

These are the exact internal string identifiers that gate disk, directory, and system volume access:

| Internal TCC Key | System Settings UI Name | What It Controls |
| --- | --- | --- |
| `kTCCServiceSystemPolicyAllFiles` | **Full Disk Access** | Unrestricted access to entire storage (Mail, Safari history, Time Machine, etc.). |
| `kTCCServiceSystemPolicyDocumentsFolder` | **Files and Folders → Documents** | Access to `~/Documents`. |
| `kTCCServiceSystemPolicyDesktopFolder` | **Files and Folders → Desktop** | Access to `~/Desktop`. |
| `kTCCServiceSystemPolicyDownloadsFolder` | **Files and Folders → Downloads** | Access to `~/Downloads`. |
| `kTCCServiceSystemPolicyNetworkVolumes` | **Files and Folders → Network Volumes** | Access to mounted network shares (SMB, AFP, NFS). |
| `kTCCServiceSystemPolicyRemovableVolumes` | **Files and Folders → Removable Volumes** | Access to external USB drives, SD cards, DMGs. |
| `kTCCServiceSystemPolicyDeveloperFiles` | **Developer Tools** | Access to build artifacts, derived data, and debugging storage. |
| `kTCCServiceSystemPolicyAppBundles` | App Bundles Policy | Access to modify or inspect other installed `.app` packages. |
| `kTCCServiceSystemPolicyAppData` | App Data Access | Protection against one app reading another sandbox/container's data. |
| `kTCCServiceSystemPolicySysAdminFiles` | System Administrator Files | Access to system administration tools, configs, and root utility caches. |

---

### 2. Primary `kTCCService*` Keys (Hardware, OS APIs & Privacy)

These keys guard hardware sensors, user data databases, and cross-process automation:

#### User Personal Data & Databases

* `kTCCServiceAddressBook` — Contacts (Legacy string still used in `tccd`)
* `kTCCServiceContactsFull` — Full Contacts access
* `kTCCServiceContactsLimited` — Limited / Selected Contacts access
* `kTCCServiceCalendar` — Calendars
* `kTCCServiceReminders` — Reminders
* `kTCCServicePhotos` — Photos library (Full access)
* `kTCCServicePhotosAdd` — Add-only Photos permission
* `kTCCServiceMediaLibrary` — Apple Music / Media library access
* `kTCCServiceFinancialData` — Apple Pay / Wallet / Financial records

#### Input, Capture & Automation (High-Risk Developer Keys)

* `kTCCServiceAccessibility` — Controlling the computer (UI scripting, simulating clicks/keystrokes)
* `kTCCServiceAppleEvents` — Scripting other applications via AppleScript/OSA (creates attribution chains)
* `kTCCServiceScreenCapture` — Screen & System Audio Recording
* `kTCCServiceListenEvent` — **Input Monitoring** (global keystroke/event tapping)
* `kTCCServicePostEvent` — Synthetic keyboard/mouse event posting
* `kTCCServiceDeveloperTool` — Debugging / spawning processes without standard SIP checks

#### Hardware & Peripherals

* `kTCCServiceCamera` — FaceTime / Webcams
* `kTCCServiceMicrophone` — Audio inputs / internal mic
* `kTCCServiceAudioCapture` — System audio loopback recording
* `kTCCServiceBluetoothAlways` — CoreBluetooth background access
* `kTCCServiceBluetoothPeripheral` — Peripheral connection access
* `kTCCServiceBluetoothWhileInUse` — Foregound-only Bluetooth access

#### Modern macOS Services & Extensions

* `kTCCServiceEndpointSecurityClient` — Endpoint Security Framework (ESF) extensions
* `kTCCServiceFileProviderDomain` — Third-party cloud providers (Google Drive, Dropbox, OneDrive)
* `kTCCServiceFileProviderPresence` — Inspecting presence of file provider data
* `kTCCServiceFSKitBlockDevice` — Custom user-space filesystem drivers (FSKit)
* `kTCCServiceSpeechRecognition` — Apple Dictation / Speech-to-text API
* `kTCCServiceSiri` — Siri integration
* `kTCCServiceNearbyInteraction` — Ultra-Wideband (UWB) / Nearby Interaction API
* `kTCCServiceFocusStatus` — Checking Do Not Disturb / Focus states
* `kTCCServicePasteboard` — Reading clipboard contents without direct user paste

---

### 3. Internal, SensorKit & Special Keys

Apple also includes specialized keys for iOS/watchOS shared codebases and internal diagnostics:

* **SensorKit Data (mainly iOS/watchOS sync):** `kTCCServiceSensorKitAmbientLightSensor`, `kTCCServiceSensorKitMotion`, `kTCCServiceSensorKitKeyboardMetrics`, `kTCCServiceSensorKitSoundDetection`, `kTCCServiceSensorKitWristTemperature`.
* **Meta Identifiers:** `kTCCService` (root identifier), `kTCCServiceAll` (used internally and by `tccutil reset All`).

---

### How to Dump the Exact, Up-to-Date List from Your Mac

To see every single key supported by the specific macOS version running on your machine, extract the strings directly from the `tccd` binary via Terminal:

```bash
strings /System/Library/PrivateFrameworks/TCC.framework/Support/tccd | grep -E "^kTCCService[A-Za-z0-9_]+" | sort -u

```

To see only the filesystem policy keys:

```bash
strings /System/Library/PrivateFrameworks/TCC.framework/Support/tccd | grep -E "^kTCCServiceSystemPolicy" | sort -u

```

To see which keys currently have active entries in your local user TCC database:

```bash
sqlite3 "$HOME/Library/Application Support/com.apple.TCC/TCC.db" "SELECT DISTINCT service FROM access ORDER BY service;"

```