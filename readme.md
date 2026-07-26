<p align="center">
  <h2 align="center">Windhawk Backup Manager</h2>
  <p align="center">A clean, modern utility to back up and restore your Windhawk configuration and mods.</p>
</p>

---

[![Download Latest Release](https://img.shields.io/badge/Download-Latest_Release-2ea44f?style=for-the-badge&logo=github&logoColor=white)](https://github.com/osmanonurkoc/Windhawk-Backup-Manager/releases/latest)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows-0078D4.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-v5.1%2B-5391FE.svg)
![Downloads](https://img.shields.io/github/downloads/osmanonurkoc/Windhawk-Backup-Manager/total)
![Release](https://img.shields.io/github/v/release/osmanonurkoc/Windhawk-Backup-Manager)

## 📸 Screenshots

<p align="center">
  <img src="screenshots/backup.png" width="45%" alt="Backup" />
  <img src="screenshots/restore.png" width="45%" alt="Restore" />
</p>

### Overview

Windhawk doesn't come with an official export or backup button out of the box. If you are setting up a fresh Windows installation or moving to a new machine, re-downloading and re-configuring all your mods manually can be a headache. 

**Windhawk Backup Manager** solves this by offering a native Windows 11 Fluent Design interface that gives you granular, selective control over what you back up or restore—including your registry settings, compiled engine binaries (`Engine\Mods`), and your custom local mod sources (`ModsSource`).

---

### Key Features

* **Auto-Elevation:** Automatically handles administrator privileges required to manage the Windhawk service and system-level directories.
* **Registry-Driven Listing:** Pulls exact active mods straight from the registry without duplicates.
* **Complete Source Backup:** Backs up ALL selected mod source files to prevent Update Available errors.
* **Precision Binary Export:** Bundles compiled engine binaries mapped accurately via LibraryFileName.
* **Selective Registry Backup:** Parses the exported registry file and strips out settings for unselected mods.
* **Selective Registry Restore:** Filters the registry file during restore to strictly import only the chosen mods.
* **Fluent Design UI:** WinUI3 style toggle switches, modern scrollbars, and dynamic mode transitions.
* **Safe Execution:** Temporarily manages Windhawk service states to prevent file locking issues.
* **Silent Native Execution:** Suppresses all native reg.exe streams to prevent console errors.
* **Theme Engine:** Auto-detects System Light/Dark mode with native Win11 DWM titlebar styling.

---

### How to Use

You can run this tool either as a pre-compiled executable or directly via the PowerShell script.

#### Option A: Running the Executable (`.exe`)
1. Download the latest release `.exe` from the Releases page.
2. Double-click the application. 
3. *Note:* The application will automatically prompt you for Administrator privileges via a UAC pop-up because it needs access to `C:\ProgramData\Windhawk` and system services.

#### Option B: Running the PowerShell Script (`.ps1`)
If you prefer running the raw script directly:
1. Download the `Windhawk_Backup_Manager.ps1` file.
2. Right-click the file and select **Run with PowerShell** (or run it from an elevated terminal). 

> **Important Note on PowerShell Execution Policy:**
> By default, Windows restricts running local scripts for security reasons. If you encounter an error stating that *script execution is disabled on this system*, you can temporarily bypass it for the current terminal session by opening PowerShell as Administrator and running:
> ```powershell
> Set-ExecutionPolicy Bypass -Scope Process -Force
> ```
> After running that command, you can launch the script normally.

---

### Author

Built by **Osman Onur Koç**  
🌐 [www.osmanonurkoc.com](https://www.www.osmanonurkoc.com)

---

### License

This project is licensed under the [MIT License](LICENSE).
