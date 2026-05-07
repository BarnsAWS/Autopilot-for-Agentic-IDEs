@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo  Autopilot for Agentic IDEs -- Google Antigravity Setup
echo ============================================================
echo.

:: ----------------------------------------------------------------
:: Locate Python or PowerShell
:: ----------------------------------------------------------------
set PYTHON_AVAILABLE=0
set PS_AVAILABLE=0

python --version >nul 2>&1
if %errorlevel% equ 0 set PYTHON_AVAILABLE=1

powershell -NoProfile -Command "exit 0" >nul 2>&1
if %errorlevel% equ 0 set PS_AVAILABLE=1

if %PYTHON_AVAILABLE% equ 0 (
    if %PS_AVAILABLE% equ 0 (
        echo [ERROR] Neither Python nor PowerShell is available.
        echo         Install Python 3.x or ensure PowerShell 5+ is available.
        exit /b 1
    )
    echo [INFO] Python not found. Using PowerShell for file operations.
)

:: ----------------------------------------------------------------
:: STEP 1 -- Deploy Global Rules file (~\.gemini\GEMINI.md)
::
:: GEMINI.md is Antigravity's always-on instruction file.
:: It is loaded into the agent's context in every session,
:: equivalent to Kiro's steering file and VS Code's .agent.md.
:: ----------------------------------------------------------------
echo [STEP 1/4] Deploying Global Rules file...
echo.

set GEMINI_DIR=%USERPROFILE%\.gemini
set RULES_FILE=%GEMINI_DIR%\GEMINI.md
set RULES_SOURCE=%~dp0antigravity_rules_content.md

if not exist "%GEMINI_DIR%" (
    mkdir "%GEMINI_DIR%"
    echo   Created directory: %GEMINI_DIR%
)

if exist "%RULES_FILE%" (
    copy /y "%RULES_FILE%" "%RULES_FILE%.pre-autopilot.bak" >nul 2>&1
    if %errorlevel% equ 0 (
        echo   Backed up existing GEMINI.md to GEMINI.md.pre-autopilot.bak
    ) else (
        echo   [WARNING] Could not create backup of GEMINI.md -- proceeding anyway.
    )
)

copy /y "%RULES_SOURCE%" "%RULES_FILE%" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Global Rules file deployed:
    echo        %RULES_FILE%
    set RULES_STATUS=OK
) else (
    echo   [ERROR] Failed to write Global Rules file.
    set RULES_STATUS=FAILED
)

:: ----------------------------------------------------------------
:: STEP 2 -- Deploy Antigravity Watchdog
:: ----------------------------------------------------------------
echo.
echo [STEP 2/4] Deploying Antigravity Watchdog...
echo.

set WATCHDOG_DIR=%USERPROFILE%\.antigravity
set WATCHDOG_FILE=%WATCHDOG_DIR%\autopilot_watchdog.ps1
set LAUNCHER_FILE=%WATCHDOG_DIR%\Start-Autopilot-Watchdog.bat

if not exist "%WATCHDOG_DIR%" (
    mkdir "%WATCHDOG_DIR%"
    echo   Created directory: %WATCHDOG_DIR%
)

:: Write the watchdog via PowerShell to avoid bat escaping issues
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$w = @'" ^& echo. ^& ^
"# autopilot_watchdog.ps1 -- Google Antigravity Autopilot Watchdog" ^& echo. ^& ^
"'@; $w | Set-Content '%WATCHDOG_FILE%' -Encoding UTF8" >nul 2>&1

:: Use a temp PS1 file to write the full watchdog cleanly
set WRITER=%TEMP%\write_ag_watchdog_%RANDOM%.ps1
(
    echo $watchdog = @'
    echo # autopilot_watchdog.ps1 -- Google Antigravity Autopilot Watchdog
    echo # Monitors Antigravity for a halted agent and sends a resume signal.
    echo #
    echo # Edit these values to tune behavior:
    echo $checkInterval  = 8    # seconds between polls (1-60)
    echo $idleThreshold  = 25   # seconds of unchanged title before halt (10-300)
    echo $cooldownPeriod = 15   # seconds to wait after resume signal (5-300)
    echo.
    echo $checkInterval  = [Math]::Max(1,  [Math]::Min(60,  $checkInterval))
    echo $idleThreshold  = [Math]::Max(10, [Math]::Min(300, $idleThreshold))
    echo $cooldownPeriod = [Math]::Max(5,  [Math]::Min(300, $cooldownPeriod))
    echo.
    echo Add-Type @"
    echo using System;
    echo using System.Runtime.InteropServices;
    echo public class WinAPI {
    echo     [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    echo }
    echo "@
    echo.
    echo Add-Type -AssemblyName System.Windows.Forms
    echo.
    echo function Get-Timestamp { return (Get-Date).ToString("HH:mm:ss") }
    echo.
    echo $lastTitle        = ""
    echo $lastActivityTime = Get-Date
    echo $resumeCount      = 0
    echo $noProcessCycles  = 0
    echo.
    echo Write-Host "[$(Get-Timestamp)] Antigravity Autopilot Watchdog started. Polling every ${checkInterval}s, halt threshold ${idleThreshold}s."
    echo.
    echo while ($true) {
    echo     Start-Sleep -Seconds $checkInterval
    echo.
    echo     $proc = Get-Process -Name "Antigravity" -ErrorAction SilentlyContinue ^| Where-Object { $_.MainWindowHandle -ne 0 } ^| Select-Object -First 1
    echo.
    echo     if (-not $proc) {
    echo         $noProcessCycles++
    echo         Write-Host "[$(Get-Timestamp)] Antigravity not running. Waiting... (cycle $noProcessCycles)"
    echo         if ($noProcessCycles -ge 360) {
    echo             Write-Host "[$(Get-Timestamp)] WARNING: Antigravity not found for 360+ consecutive cycles. Continuing to poll."
    echo             $noProcessCycles = 0
    echo         }
    echo         continue
    echo     }
    echo.
    echo     $noProcessCycles = 0
    echo     $currentTitle    = $proc.MainWindowTitle
    echo.
    echo     if ($currentTitle -ne $lastTitle) {
    echo         $lastTitle        = $currentTitle
    echo         $lastActivityTime = Get-Date
    echo     }
    echo.
    echo     $idleSeconds = [int]((Get-Date) - $lastActivityTime).TotalSeconds
    echo.
    echo     if ($idleSeconds -ge $idleThreshold) {
    echo         $resumeCount++
    echo         Write-Host "[$(Get-Timestamp)] HALT DETECTED - idle ${idleSeconds}s. Sending resume #${resumeCount}..."
    echo         $hwnd = $proc.MainWindowHandle
    echo         if ($hwnd -eq [IntPtr]::Zero) {
    echo             Write-Host "[$(Get-Timestamp)] ERROR: Window handle is zero - skipping resume attempt."
    echo         } else {
    echo             $brought = [WinAPI]::SetForegroundWindow($hwnd)
    echo             if (-not $brought) {
    echo                 Write-Host "[$(Get-Timestamp)] ERROR: SetForegroundWindow failed - skipping resume attempt."
    echo             } else {
    echo                 Start-Sleep -Milliseconds 300
    echo                 [System.Windows.Forms.SendKeys]::SendWait("continue working on the remaining tasks")
    echo                 Start-Sleep -Milliseconds 200
    echo                 [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    echo                 Write-Host "[$(Get-Timestamp)] Resume sent successfully."
    echo             }
    echo         }
    echo         Start-Sleep -Seconds $cooldownPeriod
    echo         $lastActivityTime = Get-Date
    echo     } else {
    echo         Write-Host "[$(Get-Timestamp)] Active. Idle: ${idleSeconds}s / ${idleThreshold}s threshold"
    echo     }
    echo }
    echo '@
    echo $watchdog ^| Set-Content -Path '%WATCHDOG_FILE%' -Encoding UTF8
) > "%WRITER%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%WRITER%" >nul 2>&1
if %errorlevel% equ 0 (
    echo   [OK] Watchdog deployed:
    echo        %WATCHDOG_FILE%
    set WATCHDOG_STATUS=OK
) else (
    echo   [ERROR] Failed to write watchdog script.
    set WATCHDOG_STATUS=FAILED
)
del "%WRITER%" >nul 2>&1

:: Write launcher
(
    echo @echo off
    echo start "Antigravity Autopilot Watchdog" powershell.exe -ExecutionPolicy Bypass -NoExit -File "%USERPROFILE%\.antigravity\autopilot_watchdog.ps1"
) > "%LAUNCHER_FILE%"

if %errorlevel% equ 0 (
    echo   [OK] Watchdog launcher deployed:
    echo        %LAUNCHER_FILE%
    set LAUNCHER_STATUS=OK
) else (
    echo   [ERROR] Failed to write watchdog launcher.
    set LAUNCHER_STATUS=FAILED
)

:: ----------------------------------------------------------------
:: STEP 3 -- Check Antigravity installation
:: ----------------------------------------------------------------
echo.
echo [STEP 3/4] Checking Antigravity installation...
echo.

set AG_INSTALLED=NOT FOUND
set AG_PATH=

if exist "%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe" (
    set AG_INSTALLED=INSTALLED
    set AG_PATH=%LOCALAPPDATA%\Programs\Antigravity\Antigravity.exe
)
if exist "%PROGRAMFILES%\Google\Antigravity\Antigravity.exe" (
    set AG_INSTALLED=INSTALLED
    set AG_PATH=%PROGRAMFILES%\Google\Antigravity\Antigravity.exe
)

if "%AG_INSTALLED%"=="INSTALLED" (
    echo   [OK] Antigravity: INSTALLED
    echo        %AG_PATH%
) else (
    echo   [INFO] Antigravity: NOT FOUND on this system.
    echo.
    echo   To install Google Antigravity:
    echo     1. Visit https://antigravity.google/download
    echo     2. Download the Windows x64 installer (~150-200 MB)
    echo     3. Run the .exe installer (requires Administrator)
    echo     4. During the setup wizard, select:
    echo           Development Mode: Agent-Driven
    echo           (gives the agent maximum autonomy)
    echo     5. Sign in with a personal Gmail account
    echo        (Google Workspace accounts not supported in preview)
    echo.
    echo   WSL2 is required for terminal execution on Windows:
    echo     wsl --install    (run as Administrator, then restart)
    echo.
    echo   Antigravity is FREE during public preview.
    echo   Models included: Gemini 3.1 Pro, Claude Sonnet 4.5,
    echo   Claude Opus 4.5, GPT-OSS-120B -- no API key required.
)

:: ----------------------------------------------------------------
:: STEP 4 -- Terminal policy guidance
:: ----------------------------------------------------------------
echo.
echo [STEP 4/4] In-IDE settings to apply after restart...
echo.
echo   For full autopilot operation, configure in Antigravity:
echo.
echo     Settings ^> Advanced Settings ^> Terminal
echo       Auto Execution Policy: Turbo
echo       (auto-executes all commands without approval)
echo.
echo     Settings ^> Development Mode
echo       Mode: Agent-Driven
echo       (agent has primary responsibility, minimal human intervention)
echo.
echo   If you prefer a safer default, use "Auto" mode with a deny list
echo   for commands that should always require manual approval.

:: ----------------------------------------------------------------
:: Final Summary
:: ----------------------------------------------------------------
echo.
echo ============================================================
echo  SUMMARY
echo ============================================================
echo.
echo   Files deployed:
echo     [%RULES_STATUS%]  Global Rules  : %RULES_FILE%
echo     [%WATCHDOG_STATUS%]  Watchdog      : %WATCHDOG_FILE%
echo     [%LAUNCHER_STATUS%]  Launcher      : %LAUNCHER_FILE%
echo.
echo   Next steps:
echo     1. Restart Antigravity to load the new Global Rules
echo     2. Set Development Mode to "Agent-Driven" in Settings
echo     3. Set Terminal Auto Execution to "Turbo" in Settings
echo     4. To start the watchdog for long tasks, run:
echo           %LAUNCHER_FILE%
echo.
echo   The Global Rules file (~\.gemini\GEMINI.md) instructs the
echo   Antigravity agent to:
echo     - Never pause for user confirmation
echo     - Auto-retry failed operations up to 5 times
echo     - Process all tasks sequentially before signaling completion
echo.
echo ============================================================
echo  Done.
echo ============================================================

endlocal
exit /b 0
