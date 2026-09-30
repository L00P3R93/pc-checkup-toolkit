<#
    =================================================================
      PORTABLE IT TOOLKIT
    =================================================================
    USB SETUP
      Put these two files in the root (or any folder) of your USB:
          system_inspect.ps1
          start_system_inspect.bat

    HOW TO RUN ON ANY PC
      Option A: double-click start_system_inspect.bat  (asks for admin, no policy changes)
      Option B: in a PowerShell terminal, run:
          powershell -ExecutionPolicy Bypass -File E:\system_inspect.ps1
        (replace E: with your USB drive letter)

    NAVIGATION
      Type the number of an option and press Enter.
      0 = back to main menu (from a submenu), Q = quit.

    Reports are saved ON THE USB in:
        Reports\<COMPUTER-NAME>_<date-time>\
    so you can carry every client's results with you.
#>

# =================================================================
# PERSONAL SETTINGS - edit these to make the toolkit yours
# =================================================================
$ToolkitName = "SYSTEM INSPECT TOOLKIT"      # shown at the top of every screen
$TechName    = "sntaks"          # your name, printed in headers and logs
$TechContact = "sntaksolutionsltd@gmail.com"                   # optional: phone or email, e.g. "0712 345 678"

$ErrorActionPreference = "Continue"

# =================================================================
# ADMIN CHECK (offers to relaunch elevated)
# =================================================================
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin -and $PSCommandPath) {
    Write-Host ""
    Write-Host "  You are NOT running as Administrator." -ForegroundColor Yellow
    Write-Host "  Repair tools, CHKDSK, SMART data and the Security log need admin rights." -ForegroundColor Yellow
    $ans = Read-Host "  Relaunch as Administrator now? (Y/N)"
    if ($ans -match '^[Yy]') {
        $exe = (Get-Process -Id $PID).Path
        Start-Process -FilePath $exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        exit
    }
}

# =================================================================
# SETUP
# =================================================================
$Date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Save reports next to the script (on the USB). If the USB is read-only
# or the script was pasted into a console, fall back to the Desktop.
$BaseDir = if ($PSScriptRoot) { Join-Path $PSScriptRoot "Reports" } else { $null }
$WorkDir = $null
if ($BaseDir) {
    try {
        $WorkDir = Join-Path $BaseDir "$($env:COMPUTERNAME)_$Date"
        New-Item -ItemType Directory -Path $WorkDir -Force -ErrorAction Stop | Out-Null
    } catch { $WorkDir = $null }
}
if (-not $WorkDir) {
    $WorkDir = Join-Path ([Environment]::GetFolderPath("Desktop")) "Toolkit_Report_$($env:COMPUTERNAME)_$Date"
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
}
$Log     = Join-Path $WorkDir "Technician_Log.txt"
try { $Host.UI.RawUI.WindowTitle = "$ToolkitName - $TechName" } catch {}

# =================================================================
# HELPERS
# =================================================================
function Write-Log {
    param([string]$Message, [string]$Color = "Gray")
    Add-Content -Path $Log -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
    Write-Host "  $Message" -ForegroundColor $Color
}

function Show-Header {
    param([string]$Title)
    Clear-Host
    $bar = "=" * 66
    Write-Host $bar -ForegroundColor DarkCyan
    $by = if ($TechContact) { "$TechName  |  $TechContact" } else { $TechName }
    Write-Host "   $ToolkitName" -NoNewline -ForegroundColor Cyan
    Write-Host "   by $by" -ForegroundColor DarkCyan
    Write-Host "   $Title" -ForegroundColor White
    Write-Host $bar -ForegroundColor DarkCyan
    $adminText  = if ($IsAdmin) { "YES" } else { "NO (limited mode)" }
    $adminColor = if ($IsAdmin) { "Green" } else { "Yellow" }
    Write-Host "   Computer: $env:COMPUTERNAME    Admin: " -NoNewline -ForegroundColor DarkGray
    Write-Host $adminText -ForegroundColor $adminColor
    Write-Host "   Reports : $WorkDir" -ForegroundColor DarkGray
    Write-Host $bar -ForegroundColor DarkCyan
    Write-Host ""
}

function Wait-Enter {
    Write-Host ""
    Read-Host "  Press Enter to return to the menu" | Out-Null
}

function Test-Admin {
    if (-not $IsAdmin) {
        Write-Host "  This option needs Administrator rights." -ForegroundColor Red
        Write-Host "  Restart the toolkit in an elevated PowerShell window." -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Confirm-Action {
    param([string]$Message)
    return ((Read-Host "  $Message (Y/N)") -match '^[Yy]')
}

# Shows data on screen AND appends it to a report file
function Add-Section {
    param([string]$Title, $Data, [string]$File, [switch]$List)
    if ($null -eq $Data -or @($Data).Count -eq 0) { $text = "  (no data returned)" }
    elseif (@($Data)[0] -is [string])           { $text = (@($Data) -join [Environment]::NewLine) }
    elseif ($List)                               { $text = ($Data | Format-List  | Out-String -Width 250).Trim() }
    else                                         { $text = ($Data | Format-Table -AutoSize | Out-String -Width 250).Trim() }

    Write-Host ""
    Write-Host "  === $Title ===" -ForegroundColor Yellow
    Write-Host $text
    Add-Content -Path (Join-Path $WorkDir $File) -Value @("", "=== $Title ===", $text) -Encoding UTF8
}

function Get-FolderSize {
    param([string]$Path)
    $sum = (Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object Length -Sum).Sum
    if ($sum) { return $sum } else { return 0 }
}

# =================================================================
# 1. SYSTEM & HARDWARE
# =================================================================
function Get-SystemInfo {
    Write-Log "Collecting system information..." Cyan
    $cs   = Get-CimInstance Win32_ComputerSystem
    $os   = Get-CimInstance Win32_OperatingSystem
    $bios = Get-CimInstance Win32_BIOS
    $up   = (Get-Date) - $os.LastBootUpTime

    $info = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        LoggedInUser = $env:USERNAME
        Manufacturer = $cs.Manufacturer
        Model        = $cs.Model
        SerialNumber = $bios.SerialNumber
        BIOSVersion  = $bios.SMBIOSBIOSVersion
        OS           = $os.Caption
        Version      = $os.Version
        Build        = $os.BuildNumber
        Architecture = $os.OSArchitecture
        InstallDate  = $os.InstallDate
        LastBoot     = $os.LastBootUpTime
        Uptime       = "$($up.Days)d $($up.Hours)h $($up.Minutes)m"
        TotalRAM_GB  = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
        FreeRAM_GB   = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    }
    Add-Section "System Summary" $info "SystemInfo.txt" -List
    systeminfo.exe | Out-File (Join-Path $WorkDir "SystemInfo_Full.txt") -Encoding UTF8
    Write-Log "Saved: SystemInfo.txt, SystemInfo_Full.txt" Green
}

function Get-HardwareInfo {
    Write-Log "Collecting hardware information..." Cyan
    $f = "HardwareInfo.txt"
    Add-Section "Processor" (Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores,
        NumberOfLogicalProcessors, @{n='MaxGHz';e={[math]::Round($_.MaxClockSpeed / 1000, 2)}}, LoadPercentage) $f -List
    Add-Section "Motherboard" (Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product, SerialNumber) $f -List
    Add-Section "Memory Modules" (Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, DeviceLocator,
        Manufacturer, @{n='SizeGB';e={[math]::Round($_.Capacity / 1GB, 1)}}, Speed, PartNumber) $f
    Add-Section "Graphics" (Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion,
        @{n='Resolution';e={"$($_.CurrentHorizontalResolution)x$($_.CurrentVerticalResolution)"}}) $f
    Add-Section "Physical Drives" (Get-CimInstance Win32_DiskDrive | Select-Object Model, InterfaceType, MediaType,
        @{n='SizeGB';e={[math]::Round($_.Size / 1GB, 1)}}, Status) $f
    Write-Log "Saved: HardwareInfo.txt" Green
}

function Get-DriverInfo {
    Write-Log "Checking drivers and problem devices..." Cyan
    $problems = Get-CimInstance Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
        Select-Object Name, @{n='ErrorCode';e={$_.ConfigManagerErrorCode}}, Status
    if ($problems) {
        Add-Section "Devices With Problems" $problems "Drivers.txt"
        Write-Log "$(@($problems).Count) device(s) have problems - check Device Manager." Red
    } else {
        Add-Section "Devices With Problems" @("  None - all devices report OK.") "Drivers.txt"
    }
    $drivers = Get-CimInstance Win32_PnPSignedDriver | Where-Object DeviceName |
        Select-Object DeviceName, DriverVersion, Manufacturer, DriverDate
    $drivers | Export-Csv (Join-Path $WorkDir "Drivers.csv") -NoTypeInformation -Encoding UTF8
    Write-Log "$(@($drivers).Count) drivers exported to Drivers.csv" Green
}

function Get-InstalledSoftware {
    Write-Log "Collecting installed software..." Cyan
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = Get-ItemProperty $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and -not $_.SystemComponent } |
        Select-Object DisplayName, DisplayVersion, Publisher, InstallDate |
        Sort-Object DisplayName -Unique
    $apps | Export-Csv (Join-Path $WorkDir "InstalledSoftware.csv") -NoTypeInformation -Encoding UTF8
    Add-Section "Installed Software ($(@($apps).Count) programs)" $apps "InstalledSoftware.txt"
    Write-Log "Saved: InstalledSoftware.csv" Green
}

function Get-BatteryReport {
    param([switch]$Quiet)
    if (-not (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)) {
        Write-Log "No battery detected (desktop PC). Skipping battery report." Yellow
        return
    }
    $out = Join-Path $WorkDir "BatteryReport.html"
    powercfg /batteryreport /output "$out" | Out-Null
    if (-not (Test-Path $out)) { Write-Log "Battery report could not be created." Red; return }

    $full   = (Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1).FullChargedCapacity
    $design = (Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1).DesignedCapacity
    if ($full -and $design) {
        $health = [math]::Round($full / $design * 100, 1)
        $color  = if ($health -lt 60) { "Red" } elseif ($health -lt 80) { "Yellow" } else { "Green" }
        Write-Log "Battery health: $health% of original capacity" $color
    }
    Write-Log "Saved: BatteryReport.html" Green
    if (-not $Quiet -and (Confirm-Action "Open the battery report now?")) { Invoke-Item $out }
}

# =================================================================
# 2. DISK & STORAGE
# =================================================================
function Get-DiskHealth {
    Write-Log "Checking disk health and storage..." Cyan
    $f = "DiskHealth.txt"
    try {
        Add-Section "Physical Disks" (Get-PhysicalDisk -ErrorAction Stop | Select-Object FriendlyName, MediaType,
            BusType, HealthStatus, OperationalStatus, @{n='SizeGB';e={[math]::Round($_.Size / 1GB, 1)}}) $f
    } catch { Write-Log "Get-PhysicalDisk is not available on this system." Yellow }

    $vols = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, VolumeName, FileSystem,
        @{n='SizeGB';e={[math]::Round($_.Size / 1GB, 1)}},
        @{n='FreeGB';e={[math]::Round($_.FreeSpace / 1GB, 1)}},
        @{n='FreePct';e={ if ($_.Size) { [math]::Round($_.FreeSpace / $_.Size * 100, 1) } else { 0 } }}
    Add-Section "Volumes" $vols $f
    foreach ($v in $vols) {
        if ($v.FreePct -lt 10) { Write-Log "WARNING: $($v.DeviceID) has only $($v.FreePct)% free space!" Red }
    }

    if ($IsAdmin) {
        $smart = Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction SilentlyContinue |
            Select-Object InstanceName, PredictFailure, Reason
        if ($smart) {
            Add-Section "SMART Failure Prediction" $smart $f
            if ($smart | Where-Object PredictFailure) { Write-Log "WARNING: SMART predicts a drive failure - back up now!" Red }
        } else {
            Add-Section "SMART Failure Prediction" @("  SMART data not exposed by this drive/controller.") $f
        }
        $rel = Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue |
            Select-Object DeviceId, Temperature, Wear, ReadErrorsTotal, WriteErrorsTotal, PowerOnHours
        if ($rel) { Add-Section "Reliability Counters" $rel $f }
    } else {
        Write-Log "Run as Administrator to include SMART data." Yellow
    }
    Write-Log "Saved: DiskHealth.txt" Green
}

function Invoke-ChkdskScan {
    if (-not (Test-Admin)) { return }
    $drive = (Read-Host "  Drive letter to scan [C]").Trim().TrimEnd(':')
    if (-not $drive) { $drive = "C" }
    if ($drive -notmatch '^[A-Za-z]$') { Write-Host "  Invalid drive letter." -ForegroundColor Red; return }
    Write-Log "Running read-only CHKDSK on ${drive}: (this can take a while)..." Cyan
    chkdsk.exe "${drive}:" | Tee-Object -FilePath (Join-Path $WorkDir "CHKDSK_$drive.txt")
    Write-Log "CHKDSK finished. Saved: CHKDSK_$drive.txt" Green
    Write-Host "  This was a read-only scan. To repair errors run: chkdsk ${drive}: /f" -ForegroundColor DarkGray
}

# =================================================================
# 3. NETWORK
# =================================================================
function Get-IPConfig  { Add-Section "IP Configuration" (ipconfig /all) "Network.txt" }

function Get-Adapters  {
    Add-Section "Network Adapters" (Get-NetAdapter | Select-Object Name, InterfaceDescription, Status,
        LinkSpeed, MacAddress) "Network.txt"
}

function Get-Connections {
    $procs = @{}
    Get-Process | ForEach-Object { $procs[$_.Id] = $_.ProcessName }
    $c = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort,
            @{n='Process';e={ $procs[[int]$_.OwningProcess] }} | Sort-Object Process
    Add-Section "Active TCP Connections" $c "Network.txt"
}

function Get-Routes {
    Add-Section "Routing Table (IPv4)" (Get-NetRoute -AddressFamily IPv4 | Select-Object DestinationPrefix,
        NextHop, InterfaceAlias, RouteMetric) "Network.txt"
}

function Get-ArpTable  { Add-Section "ARP Table" (arp -a) "Network.txt" }

function Test-Internet {
    Write-Log "Testing internet connectivity..." Cyan
    Add-Section "Ping 8.8.8.8" (ping -n 4 8.8.8.8) "Network.txt"
    $dns = try {
        Resolve-DnsName google.com -ErrorAction Stop | Select-Object -First 3 -Property Name, Type, IPAddress
    } catch { @("  DNS lookup FAILED: $($_.Exception.Message)") }
    Add-Section "DNS Lookup (google.com)" $dns "Network.txt"
    $web = Test-NetConnection google.com -Port 443 -WarningAction SilentlyContinue
    Add-Section "HTTPS Test (google.com:443)" ($web | Select-Object ComputerName, RemoteAddress, TcpTestSucceeded) "Network.txt"
    if ($web.TcpTestSucceeded) { Write-Log "Internet: OK" Green } else { Write-Log "Internet: FAILED" Red }
}

function Clear-DnsCacheNow {
    Add-Section "Flush DNS Cache" (ipconfig /flushdns) "Network.txt"
}

function Invoke-AllNetwork {
    Get-IPConfig; Get-Adapters; Get-Connections; Get-Routes; Get-ArpTable; Test-Internet
    Write-Log "Saved: Network.txt" Green
}

# =================================================================
# 4. EVENT LOGS & UPDATES
# =================================================================
function Get-RecentErrors {
    param([string]$LogName, [int]$Days = 7)
    Write-Log "Reading $LogName log (critical + errors, last $Days days)..." Cyan
    $ev = Get-WinEvent -FilterHashtable @{ LogName = $LogName; Level = 1, 2; StartTime = (Get-Date).AddDays(-$Days) } `
            -MaxEvents 50 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, Id, ProviderName,
            @{n='Message';e={ if ($_.Message) { ($_.Message -split "`r?`n")[0] } }}
    if ($ev) {
        Add-Section "$LogName Errors - last $Days days (max 50)" $ev "EventLogs.txt"
        Add-Section "$LogName - Top Error Sources" ($ev | Group-Object ProviderName | Sort-Object Count -Descending |
            Select-Object -First 5 Count, Name) "EventLogs.txt"
    } else {
        Add-Section "$LogName Errors - last $Days days" @("  No critical/error events found.") "EventLogs.txt"
    }
}

function Get-FailedLogons {
    if (-not (Test-Admin)) { return }
    Write-Log "Reading failed logon attempts (Security log, last 7 days)..." Cyan
    $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4625; StartTime = (Get-Date).AddDays(-7) } `
            -MaxEvents 50 -ErrorAction SilentlyContinue |
        ForEach-Object {
            $x = [xml]$_.ToXml()
            [PSCustomObject]@{
                Time    = $_.TimeCreated
                Account = ($x.Event.EventData.Data | Where-Object Name -eq 'TargetUserName').'#text'
                Source  = ($x.Event.EventData.Data | Where-Object Name -eq 'IpAddress').'#text'
            }
        }
    if ($ev) { Add-Section "Failed Logons (last 7 days)" $ev "EventLogs.txt" }
    else     { Add-Section "Failed Logons (last 7 days)" @("  No failed logons found.") "EventLogs.txt" }
}

function Export-EventLogs {
    Write-Log "Exporting event logs (.evtx)..." Cyan
    $logs = @('System', 'Application')
    if ($IsAdmin) { $logs += 'Security' }
    foreach ($l in $logs) {
        wevtutil epl $l (Join-Path $WorkDir "$l.evtx") 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Log "Exported $l.evtx" Green }
        else                     { Write-Log "Could not export $l (admin rights may be needed)" Yellow }
    }
}

function Get-UpdateHistory {
    Write-Log "Reading Windows Update history..." Cyan
    $f = "WindowsUpdates.txt"
    try {
        $searcher = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher()
        $total = $searcher.GetTotalHistoryCount()
        if ($total -gt 0) {
            $hist = $searcher.QueryHistory(0, [math]::Min($total, 40)) | Where-Object { $_.Title } |
                Select-Object Date, @{n='Result';e={
                    switch ($_.ResultCode) { 1 {'In progress'} 2 {'Succeeded'} 3 {'Succeeded w/ errors'}
                                             4 {'FAILED'} 5 {'Aborted'} default {'Unknown'} } }}, Title
            Add-Section "Update History (latest 40)" $hist $f
            $failed = @($hist | Where-Object Result -eq 'FAILED').Count
            if ($failed) { Write-Log "$failed recent update(s) FAILED." Red }
        }
    } catch { Write-Log "Windows Update API unavailable; showing hotfixes only." Yellow }
    Add-Section "Installed Hotfixes" (Get-HotFix | Sort-Object InstalledOn -Descending |
        Select-Object HotFixID, Description, InstalledOn) $f
    Write-Log "Saved: WindowsUpdates.txt" Green
}

# =================================================================
# 5. SERVICES & PROCESSES
# =================================================================
function Get-RunningServices {
    Add-Section "Running Services" (Get-Service | Where-Object Status -eq 'Running' | Sort-Object DisplayName |
        Select-Object Name, DisplayName, StartType) "Services.txt"
}

function Get-StoppedAutoServices {
    $s = Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" |
        Select-Object Name, DisplayName, State, ExitCode
    Add-Section "Automatic Services NOT Running" $s "Services.txt"
    Write-Host "  Note: some delayed/trigger-start services stop normally. Focus on non-zero ExitCodes." -ForegroundColor DarkGray
}

function Get-TopProcesses {
    $f = "Processes.txt"
    Add-Section "Top 15 by CPU Time" (Get-Process | Sort-Object CPU -Descending | Select-Object -First 15 Name, Id,
        @{n='CPU(s)';e={[math]::Round($_.CPU, 1)}}, @{n='RAM(MB)';e={[math]::Round($_.WorkingSet64 / 1MB, 1)}}) $f
    Add-Section "Top 15 by Memory" (Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name, Id,
        @{n='RAM(MB)';e={[math]::Round($_.WorkingSet64 / 1MB, 1)}}, @{n='CPU(s)';e={[math]::Round($_.CPU, 1)}}) $f
}

function Get-StartupPrograms {
    Add-Section "Startup Programs" (Get-CimInstance Win32_StartupCommand | Select-Object Name, Command,
        Location, User) "Startup.txt"
}

function Restart-SelectedService {
    if (-not (Test-Admin)) { return }
    $name = (Read-Host "  Service name (e.g. Spooler)").Trim()
    if (-not $name) { return }
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Host "  Service '$name' not found." -ForegroundColor Red; return }
    Write-Host "  $($svc.DisplayName) is currently $($svc.Status)."
    if (Confirm-Action "Restart it?") {
        try   { Restart-Service -Name $svc.Name -Force -ErrorAction Stop; Write-Log "Restarted service $($svc.Name)" Green }
        catch { Write-Log "Failed to restart $($svc.Name): $($_.Exception.Message)" Red }
    }
}

function Stop-SelectedProcess {
    $target = (Read-Host "  Process name or PID").Trim() -replace '\.exe$', ''
    if (-not $target) { return }
    $p = if ($target -match '^\d+$') { Get-Process -Id ([int]$target) -ErrorAction SilentlyContinue }
         else                        { Get-Process -Name $target -ErrorAction SilentlyContinue }
    if (-not $p) { Write-Host "  Process '$target' not found." -ForegroundColor Red; return }
    $p | Select-Object Name, Id, @{n='RAM(MB)';e={[math]::Round($_.WorkingSet64 / 1MB, 1)}} |
        Format-Table -AutoSize | Out-Host
    if (Confirm-Action "End $(@($p).Count) process(es)?") {
        try   { $p | Stop-Process -Force -ErrorAction Stop; Write-Log "Ended process(es): $target" Green }
        catch { Write-Log "Could not end process: $($_.Exception.Message)" Red }
    }
}

# =================================================================
# 6. SECURITY & FIREWALL
# =================================================================
function Get-FirewallStatus {
    Add-Section "Firewall Profiles" (Get-NetFirewallProfile | Select-Object Name, Enabled,
        DefaultInboundAction, DefaultOutboundAction) "Firewall.txt"
    $off = Get-NetFirewallProfile | Where-Object { $_.Enabled -eq 'False' }
    foreach ($p in $off) { Write-Log "WARNING: Firewall is OFF for the $($p.Name) profile!" Red }
}

function Export-FirewallRules {
    Write-Log "Exporting enabled firewall rules (may take a minute)..." Cyan
    $rules = Get-NetFirewallRule -Enabled True | Select-Object DisplayName, Direction, Action, Profile,
        @{n='Group';e={$_.DisplayGroup}}
    $rules | Export-Csv (Join-Path $WorkDir "FirewallRules.csv") -NoTypeInformation -Encoding UTF8
    Add-Section "Enabled Inbound ALLOW Rules" ($rules | Where-Object { $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' } |
        Sort-Object DisplayName | Select-Object DisplayName, Profile, Group) "Firewall.txt"
    Write-Log "Saved: FirewallRules.csv ($(@($rules).Count) rules)" Green
}

function Get-DefenderStatus {
    try {
        $d = Get-MpComputerStatus -ErrorAction Stop | Select-Object AMServiceEnabled, AntivirusEnabled,
            RealTimeProtectionEnabled, AntivirusSignatureLastUpdated, QuickScanAge, FullScanAge
        Add-Section "Microsoft Defender Status" $d "Security.txt" -List
        if (-not $d.RealTimeProtectionEnabled) { Write-Log "WARNING: Real-time protection is OFF!" Red }
    } catch {
        Add-Section "Microsoft Defender Status" @("  Unavailable (a third-party antivirus may be installed).") "Security.txt"
    }
}

function Start-DefenderQuickScan {
    try {
        Write-Log "Running Defender quick scan (a few minutes)..." Cyan
        Start-MpScan -ScanType QuickScan -ErrorAction Stop
        Write-Log "Quick scan finished." Green
        $threats = Get-MpThreatDetection -ErrorAction SilentlyContinue
        if ($threats) { Add-Section "Threat Detections" ($threats | Select-Object InitialDetectionTime, ThreatID, ActionSuccess) "Security.txt" }
        else          { Write-Log "No threats detected." Green }
    } catch { Write-Log "Quick scan failed: $($_.Exception.Message)" Red }
}

function Get-LocalAccounts {
    try {
        Add-Section "Local User Accounts" (Get-LocalUser | Select-Object Name, Enabled, LastLogon,
            PasswordRequired, PasswordLastSet) "Security.txt"
        Add-Section "Administrators Group" (Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop |
            Select-Object Name, ObjectClass, PrincipalSource) "Security.txt"
    } catch { Write-Log "Could not read local accounts: $($_.Exception.Message)" Yellow }
}

# =================================================================
# 7. WINDOWS REPAIR
# =================================================================
function New-RestorePoint {
    if (-not (Test-Admin)) { return }
    try {
        Write-Log "Creating a System Restore Point..." Cyan
        Checkpoint-Computer -Description "IT Toolkit $(Get-Date -Format 'yyyy-MM-dd HH:mm')" `
            -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log "Restore point created." Green
    } catch {
        Write-Log "Could not create restore point: $($_.Exception.Message)" Yellow
        Write-Host "  (System Protection may be off, or a point was already made in the last 24 hours.)" -ForegroundColor DarkGray
    }
}

function Invoke-DISM {
    param([ValidateSet('CheckHealth', 'ScanHealth', 'RestoreHealth')][string]$Mode)
    if (-not (Test-Admin)) { return }
    Write-Log "Running DISM /$Mode - please wait, do not close this window..." Cyan
    DISM.exe /Online /Cleanup-Image "/$Mode" | Tee-Object -FilePath (Join-Path $WorkDir "DISM_$Mode.txt")
    Write-Log "DISM $Mode finished (exit code $LASTEXITCODE). Saved: DISM_$Mode.txt" Green
}

function Invoke-SFC {
    if (-not (Test-Admin)) { return }
    Write-Log "Running SFC /scannow - usually 10-20 minutes..." Cyan
    sfc.exe /scannow
    $code = $LASTEXITCODE
    $cbs = "$env:windir\Logs\CBS\CBS.log"
    if (Test-Path $cbs) {
        Select-String -Path $cbs -Pattern '\[SR\]' -ErrorAction SilentlyContinue | ForEach-Object Line |
            Out-File (Join-Path $WorkDir "SFC_Details.txt") -Encoding UTF8
    }
    Write-Log "SFC finished (exit code $code). Saved: SFC_Details.txt" Green
}

function Invoke-FullRepair {
    if (-not (Test-Admin)) { return }
    Write-Host "  Recommended order: Restore Point -> DISM RestoreHealth -> SFC." -ForegroundColor Yellow
    Write-Host "  This can take 30+ minutes. Keep the PC plugged in." -ForegroundColor Yellow
    if (Confirm-Action "Start the full repair?") {
        New-RestorePoint
        Invoke-DISM -Mode RestoreHealth
        Invoke-SFC
        Write-Log "Full repair complete. Restart the computer when convenient." Green
    }
}

function Clear-TempFiles {
    $targets = @($env:TEMP, "$env:windir\Temp")
    $before = ($targets | ForEach-Object { Get-FolderSize $_ } | Measure-Object -Sum).Sum
    Write-Host ("  Temp files found: {0:N1} MB" -f ($before / 1MB))
    if (Confirm-Action "Delete temp files? (files in use will be skipped)") {
        foreach ($t in $targets) { Remove-Item (Join-Path $t '*') -Recurse -Force -ErrorAction SilentlyContinue }
        $after = ($targets | ForEach-Object { Get-FolderSize $_ } | Measure-Object -Sum).Sum
        Write-Log ("Temp cleanup freed {0:N1} MB" -f (($before - $after) / 1MB)) Green
    }
}

function Reset-NetworkStack {
    if (-not (Test-Admin)) { return }
    Write-Host "  This resets Winsock and TCP/IP settings. A RESTART is required afterwards." -ForegroundColor Yellow
    if (Confirm-Action "Continue?") {
        $f = "NetworkReset.txt"
        Add-Section "Winsock Reset" (netsh winsock reset) $f
        Add-Section "TCP/IP Reset"  (netsh int ip reset) $f
        Add-Section "Flush DNS"     (ipconfig /flushdns) $f
        Write-Log "Network stack reset. Please restart the computer." Green
    }
}

# =================================================================
# 8. FULL DIAGNOSTIC
# =================================================================
function Invoke-FullDiagnostic {
    $steps = @(
        @{ Name = 'System information';       Action = { Get-SystemInfo } },
        @{ Name = 'Hardware information';     Action = { Get-HardwareInfo } },
        @{ Name = 'Drivers & problem devices'; Action = { Get-DriverInfo } },
        @{ Name = 'Disk health & storage';    Action = { Get-DiskHealth } },
        @{ Name = 'Network diagnostics';      Action = { Invoke-AllNetwork } },
        @{ Name = 'System log errors';        Action = { Get-RecentErrors -LogName System } },
        @{ Name = 'Application log errors';   Action = { Get-RecentErrors -LogName Application } },
        @{ Name = 'Windows Update history';   Action = { Get-UpdateHistory } },
        @{ Name = 'Stopped auto services';    Action = { Get-StoppedAutoServices } },
        @{ Name = 'Top processes';            Action = { Get-TopProcesses } },
        @{ Name = 'Startup programs';         Action = { Get-StartupPrograms } },
        @{ Name = 'Installed software';       Action = { Get-InstalledSoftware } },
        @{ Name = 'Firewall status';          Action = { Get-FirewallStatus } },
        @{ Name = 'Defender status';          Action = { Get-DefenderStatus } },
        @{ Name = 'Battery report';           Action = { Get-BatteryReport -Quiet } }
    )
    $i = 0
    foreach ($s in $steps) {
        $i++
        Write-Progress -Activity "Full Diagnostic" -Status $s.Name -PercentComplete ($i / $steps.Count * 100)
        Write-Host ""
        Write-Host "  [$i/$($steps.Count)] $($s.Name)" -ForegroundColor Magenta
        try { & $s.Action } catch { Write-Log "Step failed: $($s.Name) - $($_.Exception.Message)" Red }
    }
    Write-Progress -Activity "Full Diagnostic" -Completed
    Write-Host ""
    Write-Log "FULL DIAGNOSTIC COMPLETE. Reports saved in: $WorkDir" Green
    Write-Host "  (CHKDSK and repair tools are not included - run them from their menus.)" -ForegroundColor DarkGray
}

# =================================================================
# MENU ENGINE
# =================================================================
function Exit-Toolkit {
    Write-Host ""
    Write-Log "Toolkit closed." DarkGray
    if (Confirm-Action "Open the report folder before exiting?") { Invoke-Item $WorkDir }
    exit
}

function Show-SubMenu {
    param([string]$Title, [array]$Items)
    while ($true) {
        Show-Header "MAIN MENU > $Title"
        foreach ($item in $Items) { Write-Host ("   {0}. {1}" -f $item.Key, $item.Label) }
        Write-Host ""
        Write-Host "   0. Back to Main Menu" -ForegroundColor Cyan
        Write-Host "   Q. Quit"              -ForegroundColor Red
        $choice = (Read-Host "`n  Select an option").Trim()

        if ($choice -eq '0' -or $choice -eq 'b') { return }
        if ($choice -eq 'q') { Exit-Toolkit }

        $selected = $Items | Where-Object { $_.Key -eq $choice }
        if ($selected) {
            Show-Header "$Title > $($selected.Label)"
            try   { & $selected.Action }
            catch { Write-Log "Error: $($_.Exception.Message)" Red }
            Wait-Enter
        } else {
            Write-Host "  Invalid choice. Try again." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}

$MenuSystem = @(
    @{ Key = '1'; Label = 'System Information';          Action = { Get-SystemInfo } },
    @{ Key = '2'; Label = 'Hardware Information';        Action = { Get-HardwareInfo } },
    @{ Key = '3'; Label = 'Drivers & Problem Devices';   Action = { Get-DriverInfo } },
    @{ Key = '4'; Label = 'Installed Software (CSV)';    Action = { Get-InstalledSoftware } },
    @{ Key = '5'; Label = 'Battery Report (laptops)';    Action = { Get-BatteryReport } }
)

$MenuDisk = @(
    @{ Key = '1'; Label = 'Disk Health, Volumes & SMART'; Action = { Get-DiskHealth } },
    @{ Key = '2'; Label = 'CHKDSK Scan (read-only)';      Action = { Invoke-ChkdskScan } }
)

$MenuNetwork = @(
    @{ Key = '1'; Label = 'IP Configuration';            Action = { Get-IPConfig } },
    @{ Key = '2'; Label = 'Network Adapters';            Action = { Get-Adapters } },
    @{ Key = '3'; Label = 'Active Connections';          Action = { Get-Connections } },
    @{ Key = '4'; Label = 'Routing Table';               Action = { Get-Routes } },
    @{ Key = '5'; Label = 'ARP Table';                   Action = { Get-ArpTable } },
    @{ Key = '6'; Label = 'Internet Connectivity Test';  Action = { Test-Internet } },
    @{ Key = '7'; Label = 'Flush DNS Cache';             Action = { Clear-DnsCacheNow } },
    @{ Key = '8'; Label = 'Run ALL Network Checks';      Action = { Invoke-AllNetwork } }
)

$MenuLogs = @(
    @{ Key = '1'; Label = 'System Log Errors (7 days)';        Action = { Get-RecentErrors -LogName System } },
    @{ Key = '2'; Label = 'Application Log Errors (7 days)';   Action = { Get-RecentErrors -LogName Application } },
    @{ Key = '3'; Label = 'Failed Logon Attempts (Security)';  Action = { Get-FailedLogons } },
    @{ Key = '4'; Label = 'Export Full Logs (.evtx)';          Action = { Export-EventLogs } },
    @{ Key = '5'; Label = 'Windows Update History';            Action = { Get-UpdateHistory } }
)

$MenuServices = @(
    @{ Key = '1'; Label = 'Running Services';                Action = { Get-RunningServices } },
    @{ Key = '2'; Label = 'Automatic Services Not Running';  Action = { Get-StoppedAutoServices } },
    @{ Key = '3'; Label = 'Top Processes (CPU / Memory)';    Action = { Get-TopProcesses } },
    @{ Key = '4'; Label = 'Startup Programs';                Action = { Get-StartupPrograms } },
    @{ Key = '5'; Label = 'Restart a Service';               Action = { Restart-SelectedService } },
    @{ Key = '6'; Label = 'End a Process';                   Action = { Stop-SelectedProcess } }
)

$MenuSecurity = @(
    @{ Key = '1'; Label = 'Firewall Profile Status';         Action = { Get-FirewallStatus } },
    @{ Key = '2'; Label = 'Export Firewall Rules (CSV)';     Action = { Export-FirewallRules } },
    @{ Key = '3'; Label = 'Microsoft Defender Status';       Action = { Get-DefenderStatus } },
    @{ Key = '4'; Label = 'Defender Quick Scan';             Action = { Start-DefenderQuickScan } },
    @{ Key = '5'; Label = 'Local Users & Administrators';    Action = { Get-LocalAccounts } }
)

$MenuRepair = @(
    @{ Key = '1'; Label = 'Create System Restore Point';         Action = { New-RestorePoint } },
    @{ Key = '2'; Label = 'DISM CheckHealth (quick)';            Action = { Invoke-DISM -Mode CheckHealth } },
    @{ Key = '3'; Label = 'DISM ScanHealth';                     Action = { Invoke-DISM -Mode ScanHealth } },
    @{ Key = '4'; Label = 'DISM RestoreHealth';                  Action = { Invoke-DISM -Mode RestoreHealth } },
    @{ Key = '5'; Label = 'SFC /scannow';                        Action = { Invoke-SFC } },
    @{ Key = '6'; Label = 'FULL Repair (Restore Pt + DISM + SFC)'; Action = { Invoke-FullRepair } },
    @{ Key = '7'; Label = 'Clear Temp Files';                    Action = { Clear-TempFiles } },
    @{ Key = '8'; Label = 'Reset Network Stack';                 Action = { Reset-NetworkStack } }
)

function Show-MainMenu {
    while ($true) {
        Show-Header "MAIN MENU"
        Write-Host "   1. System & Hardware"
        Write-Host "   2. Disk & Storage"
        Write-Host "   3. Network Diagnostics"
        Write-Host "   4. Event Logs & Updates"
        Write-Host "   5. Services & Processes"
        Write-Host "   6. Security & Firewall"
        Write-Host "   7. Windows Repair Tools"
        Write-Host "   8. Run FULL Diagnostic (all checks)" -ForegroundColor Green
        Write-Host "   9. Open Report Folder"
        Write-Host ""
        Write-Host "   0. Exit" -ForegroundColor Red
        $choice = (Read-Host "`n  Select an option").Trim()

        switch ($choice) {
            '1' { Show-SubMenu "SYSTEM & HARDWARE"     $MenuSystem }
            '2' { Show-SubMenu "DISK & STORAGE"        $MenuDisk }
            '3' { Show-SubMenu "NETWORK DIAGNOSTICS"   $MenuNetwork }
            '4' { Show-SubMenu "EVENT LOGS & UPDATES"  $MenuLogs }
            '5' { Show-SubMenu "SERVICES & PROCESSES"  $MenuServices }
            '6' { Show-SubMenu "SECURITY & FIREWALL"   $MenuSecurity }
            '7' { Show-SubMenu "WINDOWS REPAIR TOOLS"  $MenuRepair }
            '8' { Show-Header "FULL DIAGNOSTIC"; Invoke-FullDiagnostic; Wait-Enter }
            '9' { Invoke-Item $WorkDir }
            '0' { Exit-Toolkit }
            'q' { Exit-Toolkit }
            default { Write-Host "  Invalid choice. Try again." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# =================================================================
# START
# =================================================================
Write-Log "$ToolkitName started by $TechName on $env:COMPUTERNAME (Windows user: $env:USERNAME, Admin: $IsAdmin)" DarkGray
Show-MainMenu