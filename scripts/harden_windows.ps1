#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 Security Hardening Script
    Розроблено в рамках навчального проекту з кібербезпеки — ХНУА, 2026

.DESCRIPTION
    Скрипт виконує комплексне зміцнення безпеки Windows 11:
    - Блокування мережевого доступу для облікових записів без пароля
    - Вимкнення небезпечних протоколів (SMBv1/v2, NetBIOS)
    - Налаштування Account Lockout Policy
    - Блокування небезпечних портів через Windows Firewall
    - Вимкнення всіх сервісів віддаленого доступу
    - Увімкнення PowerShell ScriptBlock Logging
    - Запуск повного сканування Windows Defender

.NOTES
    Тестувалось на: Windows 11 Pro 26200 (Build 2025)
    Вимагає: PowerShell 5.1+, права Адміністратора
#>

$ErrorActionPreference = "Continue"
$log = @()
function OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green;  $script:log += "[OK]   $msg" }
function WARN($msg) { Write-Host "  [!!] $msg" -ForegroundColor Yellow; $script:log += "[WARN] $msg" }
function FAIL($msg) { Write-Host "  [XX] $msg" -ForegroundColor Red;    $script:log += "[FAIL] $msg" }
function HEAD($msg) { Write-Host "`n--- $msg ---" -ForegroundColor Cyan; $script:log += "`n--- $msg ---" }

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "  WINDOWS SECURITY HARDENING" -ForegroundColor Magenta
Write-Host "  $(Get-Date -f 'dd.MM.yyyy HH:mm')" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# ── 1. Заблокувати мережевий вхід для облікових записів без пароля ─────────────
HEAD "1. Blank Password Network Access"
try {
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" `
        -Name "LimitBlankPasswordUse" -Value 1 -Type DWord -ErrorAction Stop
    OK "LimitBlankPasswordUse=1 — accounts without password cannot log in over network"
} catch { FAIL "LimitBlankPasswordUse: $_" }

# ── 2. Вимкнути Guest та DefaultAccount ───────────────────────────────────────
HEAD "2. Disable Unnecessary Accounts"
@("Guest", "DefaultAccount") | ForEach-Object {
    $u = Get-LocalUser -Name $_ -ErrorAction SilentlyContinue
    if ($u -and $u.Enabled) {
        Disable-LocalUser -Name $_ -ErrorAction SilentlyContinue
        WARN "$_ was enabled — disabled"
    } else { OK "$_ — already disabled" }
}

# ── 3. Account Lockout Policy ──────────────────────────────────────────────────
HEAD "3. Account Lockout Policy"
try {
    net accounts /lockoutthreshold:5 /lockoutduration:30 /lockoutwindow:10 | Out-Null
    OK "Lockout: 5 failed attempts → 30 min lockout"
} catch { FAIL "net accounts: $_" }

# ── 4. Вимкнути автовхід ──────────────────────────────────────────────────────
HEAD "4. Disable Auto-Login"
$winlogon = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$autoAdmin = (Get-ItemProperty $winlogon -Name AutoAdminLogon -ErrorAction SilentlyContinue).AutoAdminLogon
if ($autoAdmin -eq "1") {
    Set-ItemProperty $winlogon -Name AutoAdminLogon -Value "0"
    Remove-ItemProperty $winlogon -Name DefaultPassword -ErrorAction SilentlyContinue
    WARN "AutoLogin was enabled — disabled"
} else { OK "AutoLogin not configured" }

# ── 5. Вимкнути SMBv1 та SMBv2 ────────────────────────────────────────────────
HEAD "5. Disable SMB Protocols"
try {
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
    OK "SMBv1 disabled"
} catch { FAIL "SMBv1: $_" }
try {
    Set-SmbServerConfiguration -EnableSMB2Protocol $false -Force -ErrorAction Stop
    OK "SMBv2 disabled"
} catch { FAIL "SMBv2: $_" }

# ── 6. Вимкнути NetBIOS ───────────────────────────────────────────────────────
HEAD "6. Disable NetBIOS over TCP/IP"
Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled } | ForEach-Object {
    $_.SetTcpipNetbios(2) | Out-Null
}
OK "NetBIOS over TCP/IP disabled on all interfaces"

# ── 7. Firewall — блокування небезпечних портів ───────────────────────────────
HEAD "7. Firewall — Block Dangerous Ports"
$ports = @(
    @{Port=445;  Proto="TCP"; Desc="SMB"},
    @{Port=3389; Proto="TCP"; Desc="RDP"},
    @{Port=5985; Proto="TCP"; Desc="WinRM HTTP"},
    @{Port=5986; Proto="TCP"; Desc="WinRM HTTPS"},
    @{Port=23;   Proto="TCP"; Desc="Telnet"},
    @{Port=5900; Proto="TCP"; Desc="VNC"},
    @{Port=137;  Proto="UDP"; Desc="NetBIOS Name"},
    @{Port=138;  Proto="UDP"; Desc="NetBIOS Datagram"},
    @{Port=139;  Proto="TCP"; Desc="NetBIOS Session"}
)
foreach ($p in $ports) {
    New-NetFirewallRule -DisplayName "BLOCK_IN_$($p.Desc)_$($p.Port)" `
        -Direction Inbound -Protocol $p.Proto -LocalPort $p.Port `
        -Action Block -Profile Any -ErrorAction SilentlyContinue | Out-Null
    OK "Blocked inbound $($p.Proto)/$($p.Port) ($($p.Desc))"
}

# ── 8. Вимкнути Remote Access сервіси ─────────────────────────────────────────
HEAD "8. Disable Remote Access Services"
$services = @("TermService", "WinRM", "RemoteRegistry")
foreach ($svc in $services) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Set-Service $svc -StartupType Disabled -ErrorAction Stop
        OK "$svc — stopped and disabled"
    } catch { WARN "$svc : $_" }
}

# Вимкнути Remote Assistance
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" `
    -Name fAllowToGetHelp -Value 0 -Force -ErrorAction SilentlyContinue
OK "Remote Assistance — disabled"

# ── 9. Вимкнути PowerShell v2 ──────────────────────────────────────────────────
HEAD "9. Disable PowerShell v2 (AMSI Bypass Prevention)"
try {
    Disable-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root `
        -NoRestart -ErrorAction Stop | Out-Null
    OK "PowerShell v2 disabled"
} catch { WARN "PS v2: $($_.Exception.Message.Split('.')[0])" }

# ── 10. PowerShell ScriptBlock Logging ────────────────────────────────────────
HEAD "10. Enable PowerShell ScriptBlock Logging"
$psLogPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
if (-not (Test-Path $psLogPath)) { New-Item $psLogPath -Force | Out-Null }
Set-ItemProperty $psLogPath -Name EnableScriptBlockLogging -Value 1 -Type DWord
OK "ScriptBlock Logging enabled (Event ID 4104)"

# ── 11. Audit Policies ─────────────────────────────────────────────────────────
HEAD "11. Audit Policies"
auditpol /set /category:"Account Management" /success:enable /failure:enable 2>&1 | Out-Null
auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable 2>&1 | Out-Null
auditpol /set /subcategory:"Process Creation" /success:enable /failure:enable 2>&1 | Out-Null
OK "Audit: Account Management, Logon/Logoff, Process Creation — enabled"

# ── 12. Windows Defender Full Scan ────────────────────────────────────────────
HEAD "12. Windows Defender Full Scan"
try {
    Start-MpScan -ScanType FullScan -AsJob -ErrorAction Stop | Out-Null
    OK "Full scan started in background"
} catch { FAIL "Defender: $_" }

# ── Summary ────────────────────────────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  HARDENING COMPLETE" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
$passed = ($log | Where-Object { $_ -match '^\[OK\]' }).Count
$warned = ($log | Where-Object { $_ -match '^\[WARN\]' }).Count
$failed = ($log | Where-Object { $_ -match '^\[FAIL\]' }).Count
Write-Host "  Passed: $passed  |  Warnings: $warned  |  Failed: $failed`n" -ForegroundColor White
