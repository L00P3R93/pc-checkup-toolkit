# PC Checkup Toolkit

**A free, portable Windows diagnostic and repair toolkit that runs from a USB flash drive.**

Check a computer's battery, hard disk, real specs, errors, network and security in a few minutes, with no installation. Built for technicians, IT support staff, and anyone buying a used, ex-UK or refurbished laptop.

<p align="center">
  <a href="https://github.com/L00P3R93/pc-checkup-toolkit/releases/latest">
    <img src="https://img.shields.io/badge/⬇_Download-Latest_Release-2ea44f?style=for-the-badge" alt="Download latest release">
  </a>
</p>

---

## Why use it?

**Buying a used or ex-UK laptop? Check it BEFORE you pay.**

| Check | What it tells you |
|---|---|
| Battery health | How much of the original capacity is left (e.g. "43%" = replace soon) |
| Disk health (SMART) | Whether the HDD/SSD is failing, worn out, or has errors |
| Real specs | The actual CPU, RAM, storage and graphics, not what the sticker or seller says |
| Serial and model | Compare them with the sticker under the laptop |
| Problem devices | Broken or missing drivers for the webcam, Wi-Fi, touchpad and more |
| Windows errors | Recent crashes, failed updates and system errors |

**For technicians and IT support:** run a full diagnostic in minutes, carry a report for every machine on your USB, and do common repairs (SFC, DISM, temp cleanup, network reset) from one menu.

---

## Quick start (no technical knowledge needed)

1. Go to the [latest release](https://github.com/L00P3R93/pc-checkup-toolkit/releases/latest) and download **PC-Checkup-Toolkit-vX.X.X.zip** under *Assets*.
   (Ignore the "Source code" files; those are for developers.)
2. Extract the ZIP and copy the **`PC-Checkup-Toolkit`** folder to your USB flash drive.
3. On any Windows PC, plug in the USB, open the folder and **double-click `start-toolkit.bat`**.
4. Click **Yes** when Windows asks for administrator permission.
5. Type a number from the menu and press **Enter**.

Reports are saved on your USB in `PC-Checkup-Toolkit\Reports\COMPUTER-NAME_date-time\`.

### Running from a PowerShell terminal

```powershell
powershell -ExecutionPolicy Bypass -File E:\PC-Checkup-Toolkit\toolkit.ps1
```

Replace `E:` with your USB drive letter. Run PowerShell **as Administrator** for full results.

---

## Menu overview

```
1. System & Hardware      System info, hardware, drivers, installed software, battery report
2. Disk & Storage         Disk health, volumes, SMART data, CHKDSK (read-only)
3. Network Diagnostics    IP config, adapters, connections, routes, ARP, internet test, flush DNS
4. Event Logs & Updates   System/app errors, failed logons, export logs, update history
5. Services & Processes   Running/stopped services, top processes, startup programs
6. Security & Firewall    Firewall status and rules, Defender status and quick scan, local admins
7. Windows Repair Tools   Restore point, DISM, SFC, full repair, temp cleanup, network reset
8. Run FULL Diagnostic    Runs all checks at once
9. Open Report Folder

0 = back to main menu    Q = quit
```

---

## Is it safe?

- **Read-only by default.** Checks only read information from the computer.
- **Nothing is sent over the internet.** All reports stay on your USB. The only network activity is the optional internet test (ping, DNS lookup, HTTPS check to google.com).
- **Changes always ask first.** Repair options, restarting services, ending processes and deleting temp files all ask for confirmation.
- **Open source.** Read every line in [`toolkit.ps1`](toolkit.ps1) before running it. You should do this with any script from the internet.

---

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 (built into Windows) or PowerShell 7
- Administrator rights for repair tools, CHKDSK, SMART data and the Security log (other checks work without admin)

---

## Troubleshooting

**"Windows protected your PC" (SmartScreen)**
Click **More info**, then **Run anyway**. This appears for any downloaded file that isn't code-signed.

**"Running scripts is disabled on this system"**
Use `start-toolkit.bat` or the `-ExecutionPolicy Bypass` command above. Neither changes any settings on the PC.

**Script is blocked after downloading**
Right-click `toolkit.ps1`, choose **Properties**, tick **Unblock** and click **OK**. Or run:
```powershell
Unblock-File E:\PC-Checkup-Toolkit\toolkit.ps1
```

**"SMART data not exposed by this drive"**
Some drives and USB enclosures don't report SMART data to Windows. The other disk checks still work.

**No battery report**
That's normal on desktop PCs, which have no battery.

---

## Customise it

Open `toolkit.ps1` in Notepad and edit the settings at the top:

```powershell
$ToolkitName = "PC CHECKUP TOOLKIT"
$TechName    = "Your Name"
$TechContact = "Your Phone Number or Email Address"
```

Your name and contact will show on every screen and in every report log.

---

## Contributing

Found a bug or have an idea? [Open an issue](../../issues) or submit a pull request. Please test changes on Windows 10+.

---

## License

[MIT](LICENSE): free to use, share and modify.

---

## Author

**Vincent Kioko**

<p>
  <a href="https://wa.me/254727796831" title="Chat on WhatsApp"><img src="docs/svg/whatsapp-icon.svg" alt="WhatsApp" width="32" height="32"></a>
  &nbsp;&nbsp;
  <a href="https://github.com/L00P3R93" title="GitHub profile"><picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/svg/GitHub_dark.svg">
    <img src="docs/svg/GitHub_light.svg" alt="GitHub" width="32" height="32">
  </picture></a>
</p>

If this toolkit helped you, give the repo a star and share it with someone buying a laptop or in IT.