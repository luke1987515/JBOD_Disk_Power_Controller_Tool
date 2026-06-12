@echo off
title AIC JBOD Disk Power Controller Tool
setlocal enabledelayedexpansion

:: Check dependencies (prefer local exe, fallback to PATH)
set "SG_SCAN=sg_scan"
set "SG_SES=sg_ses"
if exist "sg_scan.exe" set "SG_SCAN=.\sg_scan.exe"
if exist "sg_ses.exe" set "SG_SES=.\sg_ses.exe"

:MENU
cls
echo ===================================================
echo           AIC JBOD Disk Power Controller Tool
echo ===================================================
echo  [1] Power ON  Disks (Staggered, wait for OS detection)
echo  [2] Power OFF Disks (Fast shutdown, 1s delay)
echo  [3] Exit
echo ===================================================
set /p Choice=Select action (1-3): 

if "%Choice%"=="1" ( set "ACTION=ON"  & goto AUTO_DETECT )
if "%Choice%"=="2" ( set "ACTION=OFF" & goto AUTO_DETECT )
if "%Choice%"=="3" goto EXIT
echo.
echo  Error: Please enter a number between 1 and 3.
pause
goto MENU

:: ============================================================
:: AUTO_DETECT: Find P0 device (or fallback), detect disk count
:: ============================================================
:AUTO_DETECT
cls
echo ===================================================
echo  Auto-detecting AIC Enclosure  [Action: %ACTION%]
echo ===================================================
echo.
echo  Scanning for AIC expanders...

set "TARGET_SCSI="
set "FALLBACK=0"

:: Step 1: Try to find the P0 device
for /f "tokens=1" %%a in ('%SG_SCAN% -s ^| findstr "AIC" ^| findstr " P0 "') do (
    if not defined TARGET_SCSI set "TARGET_SCSI=%%a"
)

:: Step 2: Fallback to first AIC device if P0 not found
if not defined TARGET_SCSI (
    set "FALLBACK=1"
    for /f "tokens=1" %%a in ('%SG_SCAN% -s ^| findstr "AIC"') do (
        if not defined TARGET_SCSI set "TARGET_SCSI=%%a"
    )
)

:: Step 3: Abort if still no device found
if not defined TARGET_SCSI (
    echo.
    echo  [ERROR] No AIC Expander devices detected in the system.
    echo  Please make sure the JBOD is connected and powered on.
    echo.
    pause
    goto MENU
)

if "!FALLBACK!"=="1" (
    echo  [INFO] P0 device not found. Using first detected AIC device.
) else (
    echo  [INFO] P0 device found.
)
echo  [INFO] Target SCSI : !TARGET_SCSI!
echo.

:: Step 4: Detect disk slot count via Element Descriptor page
::         Use temp file to avoid CMD bracket-parsing issue with findstr regex
echo  Querying enclosure element descriptors...
%SG_SES% -p ed !TARGET_SCSI! | findstr "descriptor: Disk" > _disk_list.tmp
set "DISK_COUNT=0"
for /f %%a in ('%SG_SES% -p ed !TARGET_SCSI! ^| findstr /R /C:"descriptor: Disk[0-9]" ^| find /c /v ""') do set "DISK_COUNT=%%a"

if !DISK_COUNT! equ 0 (
    echo.
    echo  [ERROR] Could not detect disk slots for !TARGET_SCSI!.
    echo  Please check the device connection and try again.
    echo.
    pause
    goto MENU
)

echo  [INFO] Detected    : !DISK_COUNT! disk slots
goto CONFIRM

:: ============================================================
:: CONFIRM: Show summary and ask for confirmation
:: ============================================================
:CONFIRM
cls
echo ===================================================
echo                   CONFIRMATION
echo ===================================================
echo  Action     : POWER !ACTION! DISKS
echo  SCSI Target: !TARGET_SCSI!
echo  Disk Count : !DISK_COUNT! (Auto-detected)
if "!ACTION!"=="ON" (
    echo  Wait mode  : Poll sg_scan every 3s, max 180s per disk
) else (
    echo  Delay      : 1 second per disk
)
echo ===================================================
set /p CONFIRM_INPUT=Are you sure you want to proceed? (y/n): 

if /i "!CONFIRM_INPUT!"=="y"   goto EXECUTE
if /i "!CONFIRM_INPUT!"=="yes" goto EXECUTE
goto MENU

:: ============================================================
:: EXECUTE: Branch to ON or OFF
:: ============================================================
:EXECUTE
echo.
echo  Starting execution...
echo.
if "!ACTION!"=="ON" goto EXECUTE_ON
goto EXECUTE_OFF

:: ------------------------------------------------------------
:: POWER OFF: Fixed 1-second delay between each disk
:: ------------------------------------------------------------
:EXECUTE_OFF
set n=1000
for /L %%i in (1,1,!DISK_COUNT!) do (
    set /a n+=1
    set "disk_num=!n:~-3!"
    echo  [%Time%] Powering OFF Disk!disk_num! on !TARGET_SCSI!...
    %SG_SES% !TARGET_SCSI! --set=3:4:1 -D Disk!disk_num!
    ping 127.0.0.1 -n 2 >nul
)
goto EXECUTE_DONE

:: ------------------------------------------------------------
:: POWER ON: After each disk, poll sg_scan until OS detects it
::           Timeout = 180 seconds, check every 3 seconds
:: ------------------------------------------------------------
:EXECUTE_ON
:: Snapshot current non-AIC SCSI device count as baseline
%SG_SCAN% -s | findstr "SCSI" | findstr /v "AIC" > _scan_count.tmp
set "BEFORE_COUNT=0"
for /f %%a in (_scan_count.tmp) do set /a BEFORE_COUNT+=1
if exist _scan_count.tmp del /Q _scan_count.tmp

echo  [INFO] Initial SCSI disk device count: !BEFORE_COUNT!
echo.

set "DISK_IDX=0"

:EXECUTE_ON_LOOP
set /a DISK_IDX+=1
if !DISK_IDX! gtr !DISK_COUNT! goto EXECUTE_DONE

:: Format disk number with leading zeros (e.g. 001, 012, 108)
set /a disk_n=1000 + DISK_IDX
set "disk_num=!disk_n:~-3!"

echo  [%Time%] Powering ON Disk!disk_num! on !TARGET_SCSI!...
%SG_SES% !TARGET_SCSI! --clear=3:4:1 -D Disk!disk_num!

:: Poll loop
set "ELAPSED=0"

:POLL_LOOP
:: Wait ~3 seconds (4 pings = ~3s)
ping 127.0.0.1 -n 4 >nul

set "AFTER_COUNT=0"
for /f %%a in ('%SG_SCAN% -s ^| findstr "SCSI" ^| findstr /v "AIC" ^| find /c /v ""') do set "AFTER_COUNT=%%a"
for /f %%a in ('echo list disk ^| diskpart ^| findstr /R /C:"Disk [0-9]" ^| find /c /v ""') do set "AFTER_COUNT=%%a"

echo Current detected: !AFTER_COUNT!

:: New device appeared OS has recognized the disk
if !AFTER_COUNT! gtr !BEFORE_COUNT! (
    set "BEFORE_COUNT=!AFTER_COUNT!"
    echo [%Time%] Disk!disk_num! recognized by OS. Moving to next disk...
    echo.
    goto EXECUTE_ON_LOOP
)

:: Still waiting
set /a ELAPSED+=3
echo     [Waiting] Disk!disk_num! - !ELAPSED!s / 180s elapsed...

:: Timeout reached (改成單行判斷，不使用大括號，徹底防止字元解析錯誤)
if !ELAPSED! lss 180 goto POLL_LOOP

echo.
echo [WARNING] Disk!disk_num! was NOT detected by OS after 180 seconds.
set /p TIMEOUT_CHOICE=Continue to next disk anyway? (y/n): 
if /i "!TIMEOUT_CHOICE!"=="n" goto EXECUTE_DONE
echo.
goto EXECUTE_ON_LOOP

:: ============================================================
:: DONE
:: ============================================================
:EXECUTE_DONE
echo.
echo ===================================================
echo  Execution completed.
echo ===================================================
echo.
pause
goto MENU

:EXIT
echo.
echo  Exiting Tool...
timeout /t 2 >nul
exit
