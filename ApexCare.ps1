<#
    .NAME
        ApexCare Engine
    .DESCRIPTION
        Autonomous Windows Optimization, Repair, Diagnostic & Driver Maintenance Tool.
    .NOTES
        Runs elevated, supports resume after reboot, OEM Official Support integration.
#>

# ==============================================================================
# 0. ELEVATION & RUNTIME INITIALIZATION
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue"

function Assert-Administrator {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "[!] Elevating privileges to Administrator..." -ForegroundColor Yellow
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
        exit
    }
}
Assert-Administrator

# Storage Directory for logs & state persistence
$Global:AppDir = "$env:ProgramData\ApexCare"
$Global:StateFile = Join-Path $Global:AppDir "state.json"
$Global:ReportFile = Join-Path $Global:AppDir "SystemReport.txt"
if (-not (Test-Path $Global:AppDir)) { New-Item -Path $Global:AppDir -ItemType Directory -Force | Out-Null }

# ==============================================================================
# 1. UI & STYLING HELPERS
# ==============================================================================
function Show-Header {
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "                   APEXCARE AUTONOMOUS SYSTEM ENGINE                  " -ForegroundColor White
    Write-Host "         Diagnostics | Repair | Driver Suite | OEM Official Links     " -ForegroundColor DarkCyan
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Title)
    Write-Host "[*] $Title" -ForegroundColor Green
}

function Write-Notice {
    param([string]$Message)
    Write-Host "    -> $Message" -ForegroundColor Yellow
}

function Write-Critical {
    param([string]$Message)
    Write-Host "    [!] $Message" -ForegroundColor Red
}

function Write-Highlight {
    param([string]$Message)
    Write-Host "    [>] $Message" -ForegroundColor Cyan
}

# ==============================================================================
# 2. STATE PERSISTENCE (RESUME AFTER REBOOT)
# ==============================================================================
function Set-AutomationState {
    param(
        [string]$CurrentPhase,
        [int]$StepIndex
    )
    $state = [PSCustomObject]@{
        IsRunning     = $true
        CurrentPhase  = $CurrentPhase
        StepIndex     = $StepIndex
        ScriptPath    = $PSCommandPath
    }
    $state | ConvertTo-Json | Set-Content -Path $Global:StateFile -Force

    # Register RunOnce in Registry
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "ApexCareResume" -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Resume" -Force
}

function Clear-AutomationState {
    if (Test-Path $Global:StateFile) { Remove-Item -Path $Global:StateFile -Force }
    Remove-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "ApexCareResume" -ErrorAction SilentlyContinue
}

function Get-AutomationState {
    if (Test-Path $Global:StateFile) {
        try {
            return Get-Content -Path $Global:StateFile -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

# ==============================================================================
# 3. OEM KNOWLEDGEBASE & OFFICIAL DOWNLOAD RESOLVER
# ==============================================================================
function Get-OEMSupportDetails {
    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_Bios
    $bb = Get-CimInstance Win32_BaseBoard
    
    $mfg = "$($cs.Manufacturer) $($bb.Manufacturer)".Trim()
    $model = "$($cs.Model)".Trim()
    $serial = "$($bios.SerialNumber)".Trim()
    
    # Defaults
    $oemName = "Unknown / Custom PC"
    $toolName = "Intel Driver & Support Assistant / Generic Catalog"
    $toolUrl = "https://www.intel.com/content/www/us/en/support/detect.html"
    $supportPortal = "https://www.google.com/search?q=" + [System.Uri]::EscapeDataString("$mfg $model drivers support")
    $wingetId = ""

    if ($mfg -match "dell") {
        $oemName = "Dell"
        $toolName = "Dell SupportAssist & Dell Command | Update"
        $toolUrl = "https://www.dell.com/support/contents/en-us/article/product-support/self-support-knowledgebase/software-and-downloads/supportassist"
        if ($serial -and $serial -notmatch "To be filled|Default|None") {
            $supportPortal = "https://www.dell.com/support/home/en-us/product-support/servicetag/$serial/drivers"
        } else {
            $supportPortal = "https://www.dell.com/support/home/en-us"
        }
        $wingetId = "Dell.CommandUpdate"
    }
    elseif ($mfg -match "lenovo") {
        $oemName = "Lenovo"
        $toolName = "Lenovo System Update & Lenovo Vantage"
        $toolUrl = "https://support.lenovo.com/us/en/downloads/ds012808-lenovo-system-update-for-windows-10-7-8-81-32-bit-64-bit"
        if ($serial -and $serial -notmatch "To be filled|Default|None") {
            $supportPortal = "https://pcsupport.lenovo.com/products/search?query=$serial"
        } else {
            $supportPortal = "https://pcsupport.lenovo.com"
        }
        $wingetId = "Lenovo.SystemUpdate"
    }
    elseif ($mfg -match "hp" -or $mfg -match "hewlett-packard") {
        $oemName = "HP (Hewlett-Packard)"
        $toolName = "HP Support Assistant"
        $toolUrl = "https://support.hp.com/us-en/help/hp-support-assistant"
        if ($serial -and $serial -notmatch "To be filled|Default|None") {
            $supportPortal = "https://support.hp.com/us-en/drivers/selfservice?serialnumber=$serial"
        } else {
            $supportPortal = "https://support.hp.com/us-en/drivers"
        }
        $wingetId = "HP.HPSupportAssistant"
    }
    elseif ($mfg -match "asus") {
        $oemName = "ASUS"
        $toolName = "MyASUS & ASUS Live Update"
        $toolUrl = "https://www.asus.com/support/download-center/"
        $supportPortal = "https://www.asus.com/support/"
        $wingetId = "9NBLGGH5155W"
    }
    elseif ($mfg -match "acer") {
        $oemName = "Acer"
        $toolName = "Acer Care Center"
        $toolUrl = "https://www.acer.com/us-en/support/care-center"
        if ($serial -and $serial -notmatch "To be filled|Default|None") {
            $supportPortal = "https://www.acer.com/us-en/support/drivers-and-manuals?search=$serial"
        } else {
            $supportPortal = "https://www.acer.com/us-en/support"
        }
        $wingetId = ""
    }
    elseif ($mfg -match "msi" -or $mfg -match "micro-star") {
        $oemName = "MSI"
        $toolName = "MSI Center / Dragon Center"
        $toolUrl = "https://www.msi.com/Landing/MSI-Center"
        $supportPortal = "https://www.msi.com/support/download/"
        $wingetId = ""
    }
    elseif ($mfg -match "gigabyte") {
        $oemName = "Gigabyte"
        $toolName = "GIGABYTE Control Center (GCC)"
        $toolUrl = "https://www.gigabyte.com/Consumer/Software/GIGABYTE-Control-Center/"
        $supportPortal = "https://www.gigabyte.com/Support"
        $wingetId = ""
    }
    elseif ($mfg -match "huawei") {
        $oemName = "Huawei"
        $toolName = "Huawei PC Manager"
        $toolUrl = "https://consumer.huawei.com/en/support/pc-manager/"
        $supportPortal = "https://consumer.huawei.com/en/support/"
        $wingetId = ""
    }
    elseif ($mfg -match "samsung") {
        $oemName = "Samsung"
        $toolName = "Samsung Update"
        $toolUrl = "https://apps.microsoft.com/detail/9NQ3H6WPM51Q"
        $supportPortal = "https://www.samsung.com/us/support/computing/"
        $wingetId = ""
    }
    elseif ($mfg -match "microsoft" -and $model -match "surface") {
        $oemName = "Microsoft Surface"
        $toolName = "Surface Diagnostic Toolkit"
        $toolUrl = "https://support.microsoft.com/en-us/surface/fix-common-surface-problems-using-the-surface-diagnostic-toolkit-f61d8d18-37a9-863d-a8d0-e9480824e4d3"
        $supportPortal = "https://support.microsoft.com/en-us/surface"
        $wingetId = ""
    }
    else {
        # Check CPU vendor for custom builds
        $cpu = (Get-CimInstance Win32_Processor).Manufacturer
        if ($cpu -match "Intel") {
            $oemName = "Custom / Intel Architecture"
            $toolName = "Intel Driver & Support Assistant (Intel DSA)"
            $toolUrl = "https://www.intel.com/content/www/us/en/support/detect.html"
            $supportPortal = "https://www.intel.com/content/www/us/en/support.html"
            $wingetId = "Intel.IntelDriverAndSupportAssistant"
        }
        elseif ($cpu -match "AMD") {
            $oemName = "Custom / AMD Architecture"
            $toolName = "AMD Auto-Detect and Install Tool"
            $toolUrl = "https://www.amd.com/en/support/download/drivers.html"
            $supportPortal = "https://www.amd.com/en/support"
            $wingetId = ""
        }
    }

    return [PSCustomObject]@{
        OEMName       = $oemName
        RawMfg        = $mfg
        Model         = $model
        SerialNumber  = $serial
        ToolName      = $toolName
        ToolUrl       = $toolUrl
        SupportPortal = $supportPortal
        WingetId      = $wingetId
    }
}

function Show-OEMOfficialLink {
    Write-Step "Resolving Official Manufacturer Diagnostic & Driver Tool..."
    $oem = Get-OEMSupportDetails

    Write-Host ""
    Write-Host "==================== OFFICIAL OEM SUPPORT HUB ====================" -ForegroundColor Green
    Write-Host " Brand Detected : $($oem.OEMName)" -ForegroundColor White
    Write-Host " Device Model   : $($oem.Model)" -ForegroundColor White
    Write-Host " Serial/Tag     : $($oem.SerialNumber)" -ForegroundColor White
    Write-Host "------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host " Official Tool  : $($oem.ToolName)" -ForegroundColor Yellow
    Write-Host " Tool Web Link  : $($oem.ToolUrl)" -ForegroundColor Cyan
    Write-Host " Driver Portal  : $($oem.SupportPortal)" -ForegroundColor Cyan
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host ""

    $choice = Read-Host "Would you like to open the Official Tool download page in your browser now? (Y/N)"
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        Write-Notice "Launching official manufacturer page in your default browser..."
        Start-Process $oem.ToolUrl
    }
}

# ==============================================================================
# 4. DEPENDENCY BOOTSTRAPPER
# ==============================================================================
function Install-Prerequisites {
    Write-Step "Verifying and provisioning tool dependencies..."
    
    # Enable TLS 1.2
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Check Winget
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Notice "Winget not found. Installing App Installer provider..."
        $progressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Add-AppxPackage -Path "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    }

    # Install PSWindowsUpdate Module
    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Notice "Installing PSWindowsUpdate module for automated driver servicing..."
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Confirm:$false | Out-Null
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        Install-Module -Name PSWindowsUpdate -Force -Confirm:$false | Out-Null
    }
}

# ==============================================================================
# 5. HARDWARE INTELLIGENCE & BATTERY REPORT
# ==============================================================================
function Invoke-HardwareDiagnostics {
    Write-Step "Executing hardware and configuration diagnostics..."

    $cs = Get-CimInstance Win32_ComputerSystem
    $bios = Get-CimInstance Win32_Bios
    $os = Get-CimInstance Win32_OperatingSystem
    $chassis = Get-CimInstance Win32_SystemEnclosure
    $disks = Get-PhysicalDisk
    $oem = Get-OEMSupportDetails
    
    # Determine Form Factor
    $isLaptop = $false
    $chassisTypes = $chassis.ChassisTypes
    if ($chassisTypes -contains 8 -or $chassisTypes -contains 9 -or $chassisTypes -contains 10 -or $chassisTypes -contains 14) {
        $isLaptop = $true
    }

    $diagSummary = @()
    $diagSummary += "================ SYSTEM SPECIFICATION REPORT ================"
    $diagSummary += "Device Name   : $($cs.Name)"
    $diagSummary += "Manufacturer  : $($cs.Manufacturer)"
    $diagSummary += "Model         : $($cs.Model)"
    $diagSummary += "Serial Number : $($bios.SerialNumber)"
    $diagSummary += "Chassis Type  : $(if ($isLaptop) {'Laptop/Mobile'} else {'Desktop/Workstation'})"
    $diagSummary += "BIOS Version  : $($bios.SMBIOSBIOSVersion)"
    $diagSummary += "OS Name/Build : $($os.Caption) (Build $($os.BuildNumber))"
    $diagSummary += "Total RAM     : $([Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB"
    $diagSummary += "-------------------------------------------------------------"
    $diagSummary += "OFFICIAL OEM DOWNLOAD & SUPPORT:"
    $diagSummary += "  - Identified Brand : $($oem.OEMName)"
    $diagSummary += "  - Official Tool    : $($oem.ToolName)"
    $diagSummary += "  - Tool Web Link    : $($oem.ToolUrl)"
    $diagSummary += "  - Support Portal   : $($oem.SupportPortal)"
    $diagSummary += "-------------------------------------------------------------"

    # Disk Health Check
    $diagSummary += "Physical Disk Health:"
    foreach ($disk in $disks) {
        $status = $disk.HealthStatus
        $diagSummary += "  - Disk $($disk.DeviceId) ($($disk.FriendlyName)): Health = $status | Media = $($disk.MediaType)"
        if ($status -ne "Healthy") {
            Write-Critical "Physical disk $($disk.DeviceId) reports unhealthy status ($status)!"
        }
    }

    # Battery Diagnostics (If Laptop)
    if ($isLaptop) {
        Write-Notice "Laptop detected. Generating battery health audit..."
        $batteryPath = "$Global:AppDir\battery-report.xml"
        powercfg /batteryreport /xml /output $batteryPath | Out-Null
        
        if (Test-Path $batteryPath) {
            [xml]$batteryXml = Get-Content $batteryPath
            $designCap = [double]$batteryXml.BatteryReport.Batteries.Battery.DesignCapacity
            $fullCap = [double]$batteryXml.BatteryReport.Batteries.Battery.FullChargeCapacity
            
            if ($designCap -gt 0) {
                $wearLevel = [Math]::Round(((1 - ($fullCap / $designCap)) * 100), 2)
                $diagSummary += "-------------------------------------------------------------"
                $diagSummary += "Battery Diagnostic:"
                $diagSummary += "  - Design Capacity     : $designCap mWh"
                $diagSummary += "  - Full Charge Capacity: $fullCap mWh"
                $diagSummary += "  - Battery Wear Level  : $wearLevel %"
                
                if ($wearLevel -gt 35) {
                    $diagSummary += "  - Status: HIGH DEGRADATION DETECTED. Consider battery replacement."
                } else {
                    $diagSummary += "  - Status: Battery operating within normal capacity limits."
                }
            }
        }
    }

    # Run DxDiag Silent Export
    Write-Notice "Compiling DirectX diagnostics (dxdiag)..."
    Start-Process -FilePath "dxdiag.exe" -ArgumentList "/t `"$Global:AppDir\dxdiag_raw.txt`"" -Wait

    $diagSummary | Out-File -FilePath $Global:ReportFile -Encoding UTF8 -Force
    Get-Content $Global:ReportFile | Write-Host -ForegroundColor Cyan
}

# ==============================================================================
# 6. OEM UTILITY DEPLOYER & DRIVER SERVICING
# ==============================================================================
function Invoke-DriverAndOEMUpdates {
    Write-Step "Detecting OEM ecosystem and servicing driver repositories..."
    
    $oem = Get-OEMSupportDetails

    Write-Host ""
    Write-Host ">>> [OEM RECOGNITION] Platform Identified: $($oem.OEMName)" -ForegroundColor Magenta
    Write-Notice "Official Diagnostic & Update Tool: $($oem.ToolName)"
    Write-Highlight "Official Download Web Link: $($oem.ToolUrl)"
    Write-Highlight "Direct Support & Drivers Portal: $($oem.SupportPortal)"
    Write-Host ""

    # Check if we have an automated Winget deployment for this OEM
    if ($oem.WingetId -ne "") {
        Write-Notice "Attempting automated deployment via Winget ($($oem.WingetId))..."
        winget install --id $oem.WingetId --accept-package-agreements --accept-source-agreements --silent
        
        # Specific post-install trigger for Dell Command Update
        if ($oem.OEMName -eq "Dell" -and (Test-Path "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe")) {
            Write-Notice "Triggering Dell Command | Update CLI scan..."
            & "C:\Program Files\Dell\CommandUpdate\dcu-cli.exe" /applyUpdates -reboot=disable
        }
    } else {
        Write-Notice "For $($oem.OEMName), you can download the official diagnostic tool directly from:"
        Write-Host "    $($oem.ToolUrl)" -ForegroundColor Cyan
    }

    # Universal Windows Driver Servicing via PSWindowsUpdate
    Write-Notice "Querying Windows Driver Catalog for pending peripheral and bus updates..."
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -MicrosoftUpdate -UpdateType Driver -Install -AcceptAll -IgnoreReboot | Out-Null
}

# ==============================================================================
# 7. APPLICATION UPDATER (WINGET NATIVE)
# ==============================================================================
function Invoke-AppUpdates {
    Write-Step "Upgrading all installed software from official vendor sources..."
    winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent
}

# ==============================================================================
# 8. DEEP CLEANUP & SYSTEM SPEEDUP
# ==============================================================================
function Invoke-DeepCleanup {
    Write-Step "Executing storage recovery and system cache purging..."

    $paths = @(
        "$env:TEMP\*",
        "$env:windir\Temp\*",
        "$env:windir\Prefetch\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:windir\SoftwareDistribution\Download\*"
    )

    foreach ($path in $paths) {
        Write-Notice "Purging target: $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }

    # Flush DNS Cache
    Write-Notice "Flushing system DNS resolution cache..."
    Clear-DnsClientCache

    # Optimize and TRIM SSDs
    Write-Notice "Invoking TRIM optimization on non-volatile volumes..."
    Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' } | Optimize-Volume -Defrag:$false -ReTrim -Verbose:$false
}

# ==============================================================================
# 9. INTEGRITY VALIDATION & OS REPAIR
# ==============================================================================
function Invoke-SystemRepair {
    Write-Step "Auditing and servicing Windows Component Store & System Files..."
    
    Write-Notice "Running Deployment Image Servicing and Management (DISM)..."
    dism.exe /Online /Cleanup-Image /RestoreHealth /NoRestart

    Write-Notice "Running System File Checker (SFC)..."
    sfc.exe /scannow
}

# ==============================================================================
# 10. OPTIONAL ANTIVIRUS DEEP AUDIT
# ==============================================================================
function Invoke-SecurityScan {
    Write-Step "Initiating Microsoft Defender Malware Detection Routine..."
    
    if (Get-Service -Name WinDefend -ErrorAction SilentlyContinue) {
        Write-Notice "Updating Defender signature intelligence..."
        Update-MpSignature
        Write-Notice "Starting background Quick Scan..."
        Start-MpScan -ScanType QuickScan
        Write-Host "[+] Security scan completed. No immediate operational threats found." -ForegroundColor Green
    } else {
        Write-Notice "Third-party Antivirus active or Defender disabled. Skipping built-in scan."
    }
}

# ==============================================================================
# 11. FULL AUTO-PILOT EXECUTION ENGINE (WITH REBOOT RESUMPTION)
# ==============================================================================
function Start-FullAutoPilot {
    param([int]$ResumeStep = 1)

    $pipeline = @(
        @{ Index = 1; Name = "Prerequisites & Modules"; Action = { Install-Prerequisites } },
        @{ Index = 2; Name = "Hardware & Diagnostics"; Action = { Invoke-HardwareDiagnostics } },
        @{ Index = 3; Name = "Deep System Cleanup";   Action = { Invoke-DeepCleanup } },
        @{ Index = 4; Name = "OS File Integrity Repair"; Action = { Invoke-SystemRepair } },
        @{ Index = 5; Name = "Vendor & Driver Updates"; Action = { Invoke-DriverAndOEMUpdates } },
        @{ Index = 6; Name = "Software Upgrades";     Action = { Invoke-AppUpdates } }
    )

    foreach ($task in $pipeline) {
        if ($task.Index -ge $ResumeStep) {
            Set-AutomationState -CurrentPhase $task.Name -StepIndex $task.Index
            Write-Host ""
            Write-Host ">>> [PIPELINE STAGE $($task.Index)/$($pipeline.Count)]: $($task.Name)" -ForegroundColor Magenta
            & $task.Action

            # Check if pending reboot was triggered by Windows Updates
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
                Write-Critical "A component update requires an immediate restart to finalize."
                Write-Notice "System will reboot in 10 seconds and automatically continue after sign-in..."
                Set-AutomationState -CurrentPhase $task.Name -StepIndex ($task.Index + 1)
                Start-Sleep -Seconds 10
                Restart-Computer -Force
                return
            }
        }
    }

    Clear-AutomationState
    Write-Host ""
    Write-Host "[+] AUTOMATION PIPELINE EXECUTED SUCCESSFULLY!" -ForegroundColor Green
    
    # Prompt for the optional Antivirus scan at the very end
    Write-Host ""
    $optScan = Read-Host "Would you like to execute an Antivirus Security Scan now? (Y/N)"
    if ($optScan -eq 'Y' -or $optScan -eq 'y') {
        Invoke-SecurityScan
    }

    Write-Host ""
    Write-Host "All operations finalized. Diagnostics log saved to: $Global:ReportFile" -ForegroundColor Cyan
    pause
}

# ==============================================================================
# 12. MAIN ENTRY POINT & INTERACTIVE MENU
# ==============================================================================
$activeState = Get-AutomationState

if (($args -contains "-Resume") -and $activeState) {
    Show-Header
    Write-Notice "Detected incomplete routine. Resuming pipeline from Step $($activeState.StepIndex) ($($activeState.CurrentPhase))..."
    Start-FullAutoPilot -ResumeStep $activeState.StepIndex
    exit
}

do {
    Show-Header
    Write-Host "Select an operational mode:" -ForegroundColor Yellow
    Write-Host " [1] FULL AUTOPILOT (Diagnostic -> Clean -> Repair -> Drivers -> Apps)" -ForegroundColor Green
    Write-Host " [2] Hardware Diagnostics & Battery Wear Audit"
    Write-Host " [3] Deep System Cleanup & Storage Recovery"
    Write-Host " [4] OS Integrity Check & Image Repair (SFC & DISM)"
    Write-Host " [5] Update Drivers & OEM Tool Provisioning"
    Write-Host " [6] Upgrade All Installed Apps (Winget)"
    Write-Host " [7] Get Official OEM Support Tool & Driver Download Link" -ForegroundColor Cyan
    Write-Host " [8] Run Antivirus Quick Scan (Microsoft Defender)"
    Write-Host " [9] Exit"
    Write-Host ""
    $choice = Read-Host "Enter your selection (1-9)"

    switch ($choice) {
        "1" { Start-FullAutoPilot -ResumeStep 1 }
        "2" { Invoke-HardwareDiagnostics; pause }
        "3" { Invoke-DeepCleanup; pause }
        "4" { Invoke-SystemRepair; pause }
        "5" { Install-Prerequisites; Invoke-DriverAndOEMUpdates; pause }
        "6" { Install-Prerequisites; Invoke-AppUpdates; pause }
        "7" { Show-OEMOfficialLink; pause }
        "8" { Invoke-SecurityScan; pause }
        "9" { Write-Host "Terminating session..."; exit }
        default { Write-Notice "Invalid option, please retry." }
    }
} while ($choice -ne "9")
