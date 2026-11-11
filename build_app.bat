@echo off
chcp 65001 >nul
setlocal EnableExtensions
cd /d "%~dp0"

if not exist "pubspec.yaml" (
    echo *** Khong tim thay pubspec.yaml. Hay copy file nay vao thu muc goc project Flutter.
    pause
    exit /b 1
)

rem Doc ten app + version tu pubspec.yaml
set "APPNAME="
set "APPVER="
for /f "tokens=2" %%a in ('findstr /b /c:"name:" pubspec.yaml') do if not defined APPNAME set "APPNAME=%%a"
for /f "tokens=2" %%a in ('findstr /b /c:"version:" pubspec.yaml') do if not defined APPVER set "APPVER=%%a"
for /f "delims=+" %%a in ("%APPVER%") do set "APPVER=%%a"

:menu
cls
echo ==============================================
echo   BUILD APP FLUTTER
echo   Project: %CD%
echo   App: %APPNAME%   Version: %APPVER%
echo ==============================================
echo.
echo  ANDROID
echo    1. APK                      (file cai dat truc tiep)
echo    2. APK tach theo ABI        (nhe hon, nhieu file)
echo    3. AAB                      (de upload Google Play)
echo.
echo  WINDOWS
echo    4. Ban chay truc tiep       (thu muc Release co file .exe)
echo    5. Goi cai dat MSIX         (Microsoft Store)
echo    6. Goi cai dat MSIX         (cai truc tiep, chung chi tu ky)
echo    7. Bo cai dat .exe          (Inno Setup 5/6/7)
echo    M. Bo cai dat .msi          (WiX - cho doanh nghiep / GPO / Intune)
echo.
echo  LINUX  (qua WSL - tu kiem tra va cai moi truong neu thieu)
echo    8. Ban chay truc tiep       (thu muc bundle)
echo    9. Goi cai dat .deb
echo    S. Kiem tra / cai dat moi truong Linux (WSL)
echo    H. Xem huong dan cai moi truong Linux bang tay
echo.
echo  WEB
echo   10. Build web                (thu muc build\web de deploy)
echo   11. Chay thu web tren Chrome
echo.
echo  KHAC
echo    C. flutter clean + pub get
echo    L. Mo file log lan build gan nhat
echo    0. Thoat
echo.
set "CHOICE="
set /p CHOICE=Chon so: 

if /i "%CHOICE%"=="0"  exit /b 0
if /i "%CHOICE%"=="L"  goto :openlog
if /i "%CHOICE%"=="H"  goto :guide_only
if /i "%CHOICE%"=="S"  goto :linux_setup_only

rem Moi lan build ghi log moi vao build_log.txt (o thu muc project)
>build_log.txt echo Build log - %date% %time% - lua chon %CHOICE%

if /i "%CHOICE%"=="1"  goto :apk
if /i "%CHOICE%"=="2"  goto :apk_abi
if /i "%CHOICE%"=="3"  goto :aab
if /i "%CHOICE%"=="4"  goto :win_run
if /i "%CHOICE%"=="5"  goto :win_msix_store
if /i "%CHOICE%"=="6"  goto :win_msix_local
if /i "%CHOICE%"=="7"  goto :win_inno
if /i "%CHOICE%"=="M"  goto :win_msi
if /i "%CHOICE%"=="8"  goto :linux_run
if /i "%CHOICE%"=="9"  goto :linux_deb
if /i "%CHOICE%"=="10" goto :web_build
if /i "%CHOICE%"=="11" goto :web_run
if /i "%CHOICE%"=="C"  goto :clean
echo Lua chon khong hop le.
pause
goto :menu

:: ---------------- ANDROID ----------------
:apk
call :run flutter pub get
if errorlevel 1 goto :fail
call :run flutter build apk --release
if errorlevel 1 goto :fail
set "OUT=build\app\outputs\flutter-apk"
goto :done

:apk_abi
call :run flutter pub get
if errorlevel 1 goto :fail
call :run flutter build apk --release --split-per-abi
if errorlevel 1 goto :fail
set "OUT=build\app\outputs\flutter-apk"
goto :done

:aab
call :run flutter pub get
if errorlevel 1 goto :fail
call :run flutter build appbundle --release
if errorlevel 1 goto :fail
set "OUT=build\app\outputs\bundle\release"
goto :done

:: ---------------- WINDOWS ----------------
:win_run
call :run flutter pub get
if errorlevel 1 goto :fail
call :run flutter build windows --release
if errorlevel 1 goto :fail
set "OUT=build\windows\x64\runner\Release"
echo.
echo Luu y: khi gui cho nguoi khac phai gui CA thu muc Release, khong chi file .exe.
goto :done

:win_msix_store
set "VER="
set /p VER=Nhap version moi (vd 1.0.1.0, so cuoi phai la 0) hoac Enter de giu nguyen: 
set "MSIXARGS=--store"
if not "%VER%"=="" set "MSIXARGS=--store --version %VER%"
call :run flutter pub get
if errorlevel 1 goto :fail
call :run dart run msix:create %MSIXARGS%
if errorlevel 1 goto :fail
set "OUT=build\windows\x64\runner\Release"
goto :done

:win_msix_local
set "VER="
set /p VER=Nhap version moi (vd 1.0.1.0) hoac Enter de giu nguyen: 
set "MSIXARGS=--store false"
if not "%VER%"=="" set "MSIXARGS=--store false --version %VER%"
echo.
echo ============================================================
echo  MSIX "tu ky" la gi?
echo  - Goi duoc ky bang chung chi TU TAO (thu nghiem), khong phai
echo    chung chi cua to chuc tin cay (CA) nen Windows khong tin tuong.
echo  - May build: cong cu msix thuong tu cai chung chi nay (can Admin).
echo  - May khac: bao loi "publisher khong dang tin cay" cho den khi
echo    cai chung chi vao Local Machine ^> Trusted People (can Admin).
echo  - Muon gui cho nguoi dung ma khong phai lam buoc tren: dung muc 5
echo    (Store tu ky ho), mua chung chi ky ma (code signing), hoac dung
echo    muc 7 / M (khong can cai chung chi, chi bi SmartScreen canh bao).
echo ============================================================
echo Neu pubspec.yaml dang co "store: true" va lenh khong ghi de duoc,
echo hay doi tam thanh "store: false".
echo.
call :run flutter pub get
if errorlevel 1 goto :fail
call :run dart run msix:create %MSIXARGS%
if errorlevel 1 goto :fail
set "OUT=build\windows\x64\runner\Release"
goto :done

:win_inno
call :find_iscc
if not defined ISCC call :ask_iscc
if not defined ISCC goto :menu
echo Dung Inno Setup: %ISCC%
call :run flutter pub get
if errorlevel 1 goto :fail
call :run flutter build windows --release
if errorlevel 1 goto :fail
if exist "installer.iss" goto :inno_compile
echo Chua co installer.iss, dang tao file mac dinh...
(
echo [Setup]
echo AppName=%APPNAME%
echo AppVersion=%APPVER%
echo DefaultDirName={autopf}\%APPNAME%
echo DefaultGroupName=%APPNAME%
echo OutputDir=build\installer
echo OutputBaseFilename=%APPNAME%_setup_%APPVER%
echo ArchitecturesAllowed=x64compatible
echo ArchitecturesInstallIn64BitMode=x64compatible
echo UninstallDisplayIcon={app}\%APPNAME%.exe
echo Compression=lzma
echo SolidCompression=yes
echo [Files]
echo Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion
echo [Icons]
echo Name: "{group}\%APPNAME%"; Filename: "{app}\%APPNAME%.exe"
echo Name: "{autodesktop}\%APPNAME%"; Filename: "{app}\%APPNAME%.exe"
echo [Run]
echo Filename: "{app}\%APPNAME%.exe"; Description: "Chay ung dung"; Flags: nowait postinstall skipifsilent
) > installer.iss
echo Da tao installer.iss (ban co the sua file nay: icon, ten hien thi, ...).
:inno_compile
call :run ISCC.exe installer.iss
if errorlevel 1 goto :fail
set "OUT=build\installer"
goto :done

:: Tim ISCC.exe: PATH -> thu muc thuong gap (ca ban cai theo user) -> registry
:find_iscc
set "ISCC="
for /f "delims=" %%p in ('where ISCC.exe 2^>nul') do set "ISCC=%%p"
if defined ISCC goto :fi_found
set "PF86=%ProgramFiles(x86)%"
for %%R in ("%PF86%" "%ProgramFiles%" "%LocalAppData%\Programs") do for /d %%D in ("%%~R\Inno Setup*") do if exist "%%~D\ISCC.exe" set "ISCC=%%~D\ISCC.exe"
if defined ISCC goto :fi_found
for %%H in (HKLM HKCU) do for %%V in (7 6 5) do call :reg_iscc %%H %%V
if not defined ISCC exit /b 0
:fi_found
for %%I in ("%ISCC%") do set "PATH=%PATH%;%%~dpI"
exit /b 0

:reg_iscc
if defined ISCC exit /b 0
for %%K in ("SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall") do for /f "tokens=2,*" %%a in ('reg query "%1\%%~K\Inno Setup %2_is1" /v InstallLocation 2^>nul ^| findstr /i InstallLocation') do if exist "%%b\ISCC.exe" set "ISCC=%%b\ISCC.exe"
exit /b 0

:ask_iscc
echo.
echo *** Khong tim thay ISCC.exe (Inno Setup). Da tim trong: PATH, Program Files,
echo     Program Files (x86), %%LocalAppData%%\Programs va Registry (Inno Setup 5/6/7).
echo     Tai Inno Setup: https://jrsoftware.org/isdl.php
echo     Neu da cai o noi khac, nhap duong dan day du toi ISCC.exe.
set "ISCC="
set /p ISCC=Duong dan ISCC.exe (Enter de quay lai): 
if not defined ISCC exit /b 0
set "ISCC=%ISCC:"=%"
if not exist "%ISCC%" echo Khong thay file: %ISCC% & set "ISCC=" & pause & exit /b 0
for %%I in ("%ISCC%") do set "PATH=%PATH%;%%~dpI"
exit /b 0

:win_msi
set "MSIVER=%APPVER%"
for /f "delims=-" %%a in ("%APPVER%") do set "MSIVER=%%a"
where dotnet >nul 2>nul
if errorlevel 1 goto :msi_nodotnet
set "PATH=%PATH%;%USERPROFILE%\.dotnet\tools"
where wix >nul 2>nul
if errorlevel 1 call :msi_getwix
where wix >nul 2>nul
if errorlevel 1 goto :menu
call :run flutter pub get
if errorlevel 1 goto :fail
call :run flutter build windows --release
if errorlevel 1 goto :fail
if exist "installer.wxs" findstr /c:"AppFiles" installer.wxs >nul 2>nul
if exist "installer.wxs" if errorlevel 1 call :msi_oldwxs
if exist "installer.wxs" goto :msi_compile
echo Chua co installer.wxs, dang tao file mac dinh...
set "UPG="
for /f %%g in ('powershell -NoProfile -Command "[guid]::NewGuid().ToString().ToUpper()"') do set "UPG=%%g"
call :extract WXS installer.wxs
powershell -NoProfile -Command "$p='installer.wxs'; (Get-Content -Raw -LiteralPath $p).Replace('@APPNAME@','%APPNAME%').Replace('@APPVER@','%MSIVER%').Replace('@UPGRADE@','%UPG%') | Set-Content -LiteralPath $p -Encoding UTF8"
echo Da tao installer.wxs (UpgradeCode=%UPG%). GIU NGUYEN UpgradeCode cho cac ban sau
echo de MSI moi tu dong nang cap len ban cu. Ban co the sua file nay: ten hang, icon...
:msi_compile
if not exist "build\installer" mkdir "build\installer"
call :extract PS build\harvest.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File build\harvest.ps1 -Src build\windows\x64\runner\Release -Exe %APPNAME%.exe -Out build\installer\files.wxs
if errorlevel 1 goto :fail
call :run wix build installer.wxs build\installer\files.wxs -arch x64 -o build\installer\%APPNAME%_setup_%APPVER%.msi
if errorlevel 1 goto :fail
set "OUT=build\installer"
goto :done

:msi_oldwxs
echo installer.wxs cu khong co danh sach file day du, da doi ten thanh installer.wxs.bak va se tao lai.
move /y installer.wxs installer.wxs.bak >nul
exit /b 0

:msi_nodotnet
echo.
echo *** Chua cai .NET SDK (can de cai WiX). Tai: https://dotnet.microsoft.com/download
echo     hoac chay: winget install Microsoft.DotNet.SDK.8
pause
goto :menu

:msi_getwix
echo.
echo *** Chua cai WiX Toolset (cong cu tao .msi).
echo     [5] Cai WiX 5.0.2  (khong thuoc co che phi OSMF)
echo     [7] Cai WiX 7      (moi nhat; phai chap nhan EULA/OSMF, xem https://wixtoolset.org/osmf/)
echo     [Q] Quay lai
set "ANS="
set /p ANS=Chon 5/7/Q: 
if /i "%ANS%"=="5" dotnet tool install --global wix --version 5.0.2
if /i "%ANS%"=="7" dotnet tool install --global wix --version 7.0.0
if /i "%ANS%"=="7" echo Doc dieu khoan roi chay lenh sau de chap nhan: wix eula accept wix7
pause
exit /b 0

:: ---------------- LINUX ----------------
:linux_run
call :linux_prepare
if errorlevel 1 goto :linux_abort
call :run wsl -- bash -l build/linux_build.sh
if errorlevel 1 goto :fail
set "OUT=build\linux"
goto :done

:linux_deb
call :linux_prepare
if errorlevel 1 goto :linux_abort
call :run wsl -- bash -l build/linux_build.sh
if errorlevel 1 goto :fail
call :run wsl -- bash -l build/linux_deb.sh
if errorlevel 1 goto :fail
set "OUT=build\deb"
goto :done

:linux_abort
echo.
echo Chua the build Linux. Chon S de kiem tra/cai moi truong, hoac H de xem huong dan.
pause
goto :menu

:linux_setup_only
call :linux_prepare
if not errorlevel 1 echo. & echo Moi truong Linux (WSL) da day du, san sang build.
pause
goto :menu

:guide_only
if not exist "build" mkdir "build"
call :linux_guide
goto :menu

:: Kiem tra WSL + goi + Flutter. Tra ve errorlevel 0 neu san sang.
:linux_prepare
if not exist "build" mkdir "build"
call :extract SH_CHECK build\linux_check.sh
call :extract SH_SETUP build\linux_setup.sh
call :extract SH_BUILD build\linux_build.sh
call :extract SH_DEB build\linux_deb.sh
where wsl >nul 2>nul
if errorlevel 1 goto :lp_nowsl
set "WSLTEST="
for /f "delims=" %%a in ('wsl -e echo WSLOK ^<nul 2^>nul') do set "WSLTEST=%%a"
if "%WSLTEST%"=="WSLOK" goto :lp_check

:lp_nowsl
echo.
echo *** WSL/Ubuntu chua san sang (chua cai, chua co ban Linux, hoac WSL bi loi).
echo     [A] Tu dong chay: wsl --install -d Ubuntu
echo     [G] Xem huong dan cai tung buoc
echo     [Q] Quay lai
set "ANS="
set /p ANS=Chon A/G/Q: 
if /i "%ANS%"=="A" goto :lp_install
if /i "%ANS%"=="G" call :linux_guide
exit /b 1

:lp_install
wsl --install -d Ubuntu
echo.
echo Sau khi cai xong: dat username/password trong cua so Ubuntu, khoi dong lai may
echo neu duoc yeu cau, roi chay lai muc nay. Neu van loi, chon G de xem huong dan.
pause
exit /b 1

:lp_check
wsl -- bash -l build/linux_check.sh
if not errorlevel 1 exit /b 0
echo.
echo *** Moi truong Linux con thieu (xem danh sach o tren).
echo     [A] Tu dong cai dat (hoi mat khau Ubuntu, mat vai phut)
echo     [G] Xem huong dan cai bang tay
echo     [Q] Quay lai
set "ANS="
set /p ANS=Chon A/G/Q: 
if /i "%ANS%"=="A" goto :lp_setup
if /i "%ANS%"=="G" call :linux_guide
exit /b 1

:lp_setup
wsl -- bash -l build/linux_setup.sh
echo.
echo --- Kiem tra lai ---
wsl -- bash -l build/linux_check.sh
if errorlevel 1 goto :lp_setup_fail
echo Cai dat moi truong Linux thanh cong.
exit /b 0

:lp_setup_fail
echo.
echo *** Cai dat tu dong chua hoan tat (xem loi o tren).
echo     [G] Xem huong dan cai bang tay
echo     [Q] Quay lai
set "ANS="
set /p ANS=Chon G/Q: 
if /i "%ANS%"=="G" call :linux_guide
exit /b 1

:linux_guide
call :extract GUIDE build\HUONG_DAN_LINUX.txt
echo.
powershell -NoProfile -Command "Get-Content -LiteralPath 'build\HUONG_DAN_LINUX.txt'"
echo.
echo (Huong dan da luu tai: %CD%\build\HUONG_DAN_LINUX.txt)
set "OPENG="
set /p OPENG=Mo huong dan bang Notepad? (Y/N): 
if /i "%OPENG%"=="Y" start notepad "build\HUONG_DAN_LINUX.txt"
pause
exit /b 0

:: Tach doan script/huong dan nam o cuoi file bat nay ra file rieng
:extract
powershell -NoProfile -Command "$t='#%~1:'; $l=@(Get-Content -LiteralPath '%~f0' | Where-Object { $_.StartsWith($t) } | ForEach-Object { $_.Substring($t.Length) }); [IO.File]::WriteAllText((Join-Path (Get-Location) '%~2'), (($l -join [string][char]10) + [string][char]10))"
exit /b 0

:: ---------------- WEB ----------------
:web_build
call :run flutter pub get
if errorlevel 1 goto :fail
call :run flutter build web --release
if errorlevel 1 goto :fail
set "OUT=build\web"
goto :done

:web_run
call :run flutter pub get
if errorlevel 1 goto :fail
call flutter run -d chrome --release
pause
goto :menu

:: ---------------- KHAC ----------------
:clean
call :run flutter clean
call :run flutter pub get
echo.
pause
goto :menu

:openlog
if exist "build_log.txt" (start notepad build_log.txt) else (echo Chua co file log.& pause)
goto :menu

:: ---------------- CHAY LENH + GHI LOG ----------------
:run
rem Hien output ra man hinh dong thoi ghi vao build_log.txt, tra ve exit code that
set "CMDLINE=%*"
>>build_log.txt echo.
>>build_log.txt echo ===== %*
powershell -NoProfile -Command "$c=$env:CMDLINE+' 2>&1'; cmd /d /c $c | ForEach-Object { $_; Add-Content -LiteralPath 'build_log.txt' -Value $_ }; exit $LASTEXITCODE"
exit /b %errorlevel%

:: ---------------- KET THUC ----------------
:done
echo.
echo ==============================================
echo   HOAN TAT. Ket qua nam o: %CD%\%OUT%
echo ==============================================
if exist "%OUT%" explorer "%OUT%"
pause
goto :menu

:fail
echo.
echo ==============================================
echo   *** BUILD THAT BAI ***
echo   Log day du: %CD%\build_log.txt
echo ==============================================
echo ----- 40 dong cuoi cua log -----
powershell -NoProfile -Command "Get-Content -LiteralPath 'build_log.txt' -Tail 40"
echo --------------------------------
if "%CHOICE%"=="8" echo GOI Y: neu loi do thieu goi/Flutter/Rust trong Ubuntu, chon S de kiem tra va cai dat.
if "%CHOICE%"=="9" echo GOI Y: neu loi do thieu goi/Flutter/Rust trong Ubuntu, chon S de kiem tra va cai dat.
findstr /i /c:"cargo" /c:"rustc" /c:"rustup" build_log.txt >nul 2>nul
if not errorlevel 1 echo GOI Y: log co nhac den Rust (cargo). Chon S de cai Rust trong Ubuntu roi build lai.
findstr /i /c:"required packages were not found" build_log.txt >nul 2>nul
if not errorlevel 1 echo GOI Y: thieu thu vien dev trong Ubuntu. Xem ten sau "were not found" trong log (vd libsecret-1) va chay: sudo apt install -y ten-dev
findstr /i /c:"WIX7015" /c:"OSMF" build_log.txt >nul 2>nul
if not errorlevel 1 echo GOI Y: WiX 7 can chap nhan EULA/OSMF. Doc https://wixtoolset.org/osmf/ roi chay: wix eula accept wix7 (hoac cai WiX 5.0.2).
set "OPENLOG="
set /p OPENLOG=Mo file log bang Notepad? (Y/N): 
if /i "%OPENLOG%"=="Y" start notepad build_log.txt
pause
goto :menu

exit /b 0

rem ===================================================================
rem Cac dong ben duoi la du lieu (script Linux + huong dan), khong phai lenh
rem ===================================================================
#SH_CHECK:#!/bin/bash
#SH_CHECK:miss=0
#SH_CHECK:for p in curl git unzip xz-utils zip rsync clang cmake ninja-build pkgconf libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev build-essential; do
#SH_CHECK:  dpkg -s "$p" >/dev/null 2>&1 || { echo "THIEU goi: $p"; miss=1; }
#SH_CHECK:done
#SH_CHECK:f=$(command -v flutter || true)
#SH_CHECK:case "$f" in
#SH_CHECK:  ""|/mnt/*) echo "THIEU Flutter ben trong Ubuntu (khong dung duoc Flutter cua Windows)"; miss=1;;
#SH_CHECK:esac
#SH_CHECK:if grep -qiE 'native_toolchain_rust|libsql_dart|flutter_rust_bridge' pubspec.lock pubspec.yaml 2>/dev/null; then
#SH_CHECK:  if ! { command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]; }; then
#SH_CHECK:    echo "THIEU Rust (rustup) - du an dung goi native Rust (libsql_dart)"; miss=1
#SH_CHECK:  fi
#SH_CHECK:fi
#SH_CHECK:if [ "$miss" = "0" ]; then echo "Moi truong Linux: DAY DU"; fi
#SH_CHECK:exit $miss
#SH_SETUP:#!/bin/bash
#SH_SETUP:set -e
#SH_SETUP:echo "== [1/4] Cai goi he thong (nhap mat khau Ubuntu neu duoc hoi) =="
#SH_SETUP:sudo apt-get update
#SH_SETUP:sudo apt-get install -y curl git unzip xz-utils zip rsync libglu1-mesa clang cmake ninja-build pkgconf libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev build-essential
#SH_SETUP:echo "== [2/4] Cai Flutter =="
#SH_SETUP:if [ ! -x "$HOME/flutter/bin/flutter" ]; then
#SH_SETUP:  git clone https://github.com/flutter/flutter.git -b stable "$HOME/flutter"
#SH_SETUP:fi
#SH_SETUP:grep -q 'flutter/bin' "$HOME/.profile" 2>/dev/null || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> "$HOME/.profile"
#SH_SETUP:export PATH="$HOME/flutter/bin:$PATH"
#SH_SETUP:flutter config --enable-linux-desktop
#SH_SETUP:flutter --version
#SH_SETUP:echo "== [3/4] Cai Rust (can cho mot so goi native nhu libsql_dart) =="
#SH_SETUP:if [ ! -x "$HOME/.cargo/bin/rustup" ] && ! command -v rustup >/dev/null 2>&1; then
#SH_SETUP:  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
#SH_SETUP:fi
#SH_SETUP:. "$HOME/.cargo/env"
#SH_SETUP:grep -q '.cargo/env' "$HOME/.profile" 2>/dev/null || echo '. "$HOME/.cargo/env"' >> "$HOME/.profile"
#SH_SETUP:rustup default stable
#SH_SETUP:rustup show active-toolchain
#SH_SETUP:echo "== [4/4] Flutter doctor =="
#SH_SETUP:flutter doctor || true
#SH_SETUP:echo "SETUP XONG"
#SH_BUILD:#!/bin/bash
#SH_BUILD:set -e
#SH_BUILD:if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
#SH_BUILD:SRC="$(pwd)"
#SH_BUILD:N=$(grep -m1 '^name:' pubspec.yaml | awk '{print $2}' | tr -d '\r')
#SH_BUILD:V=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1 | tr -d '\r')
#SH_BUILD:W="$HOME/.wsl_build/$N"
#SH_BUILD:mkdir -p "$W"
#SH_BUILD:echo "== Dong bo ma nguon sang o Linux: $W (tranh loi quyen file tren o Windows) =="
#SH_BUILD:rsync -a --delete --exclude='/build' --exclude='/.dart_tool' --exclude='/.git' --exclude='ephemeral' --exclude='.gradle' --exclude='/build_log.txt' "$SRC"/ "$W"/
#SH_BUILD:cd "$W"
#SH_BUILD:flutter pub get
#SH_BUILD:# Va json.hpp cu cua flutter_secure_storage_linux: clang moi coi 'operator "" _json' la loi (-Werror)
#SH_BUILD:find "$HOME/.pub-cache/hosted" -path '*flutter_secure_storage_linux*' -name json.hpp -exec sed -i -E 's/operator[[:space:]]*""[[:space:]]+_json/operator ""_json/g' {} + 2>/dev/null || true
#SH_BUILD:flutter build linux --release
#SH_BUILD:B=build/linux/x64/release/bundle
#SH_BUILD:echo "== Chep ket qua ve project =="
#SH_BUILD:mkdir -p "$SRC/build/linux"
#SH_BUILD:tar -czf "$SRC/build/linux/${N}_${V}_linux_x64.tar.gz" -C "$B" .
#SH_BUILD:rm -rf "$SRC/build/linux/bundle"
#SH_BUILD:mkdir -p "$SRC/build/linux/bundle"
#SH_BUILD:cp -r "$B"/. "$SRC/build/linux/bundle/"
#SH_BUILD:echo "BUILD LINUX XONG: build/linux/${N}_${V}_linux_x64.tar.gz"
#SH_DEB:#!/bin/bash
#SH_DEB:set -e
#SH_DEB:N=$(grep -m1 '^name:' pubspec.yaml | awk '{print $2}' | tr -d '\r')
#SH_DEB:V=$(grep -m1 '^version:' pubspec.yaml | awk '{print $2}' | cut -d+ -f1 | tr -d '\r')
#SH_DEB:P=$(echo "$N" | tr '_' '-')
#SH_DEB:W="$HOME/.wsl_build/$N"
#SH_DEB:B="$W/build/linux/x64/release/bundle"
#SH_DEB:[ -x "$B/$N" ] || { echo "Khong thay file chay $B/$N (ten binary co the khac ten trong pubspec.yaml)"; exit 1; }
#SH_DEB:D=/tmp/deb_$P
#SH_DEB:rm -rf "$D"
#SH_DEB:mkdir -p "$D/DEBIAN" "$D/opt/$P" "$D/usr/bin" "$D/usr/share/applications" build/deb
#SH_DEB:cp -r "$B"/. "$D/opt/$P/"
#SH_DEB:ln -s "/opt/$P/$N" "$D/usr/bin/$P"
#SH_DEB:printf 'Package: %s\nVersion: %s\nSection: utils\nPriority: optional\nArchitecture: amd64\nDepends: libgtk-3-0\nMaintainer: dev <dev@example.com>\nDescription: %s\n' "$P" "$V" "$N" > "$D/DEBIAN/control"
#SH_DEB:printf '[Desktop Entry]\nType=Application\nName=%s\nExec=/usr/bin/%s\nTerminal=false\nCategories=Utility;\n' "$N" "$P" > "$D/usr/share/applications/$P.desktop"
#SH_DEB:chmod 755 "$D/DEBIAN"
#SH_DEB:dpkg-deb --root-owner-group --build "$D" "build/deb/${P}_${V}_amd64.deb"
#SH_DEB:echo "DEB XONG: build/deb/${P}_${V}_amd64.deb"
#GUIDE:=====================================================================
#GUIDE: HUONG DAN CAI MOI TRUONG BUILD LINUX (WSL) BANG TAY
#GUIDE:=====================================================================
#GUIDE:Chi can khi build Linux (muc 8, 9). Android/Windows/Web khong can.
#GUIDE:
#GUIDE:BUOC 1 - Bat tinh nang Windows
#GUIDE:  - Bam Start, go: optionalfeatures
#GUIDE:  - Tick: "Virtual Machine Platform" va "Windows Subsystem for Linux"
#GUIDE:  - Khoi dong lai may.
#GUIDE:
#GUIDE:BUOC 2 - Cai WSL va Ubuntu (mo PowerShell)
#GUIDE:  wsl --update
#GUIDE:  wsl --install -d Ubuntu
#GUIDE:  Cua so Ubuntu hien ra: dat username va password (nho password de dung sudo).
#GUIDE:  Kiem tra: wsl -l -v   (Ubuntu phai o VERSION 2)
#GUIDE:  Neu bao "WSL installation appears to be corrupted" / REGDB_E_CLASSNOTREG:
#GUIDE:    - Bam phim bat ky de Windows tu sua, hoac
#GUIDE:    - Mo PowerShell quyen Administrator: wsl --install --no-distribution
#GUIDE:      roi khoi dong lai may, sau do chay lai buoc nay.
#GUIDE:
#GUIDE:BUOC 3 - Cai cac goi can thiet (trong cua so Ubuntu, chay MOT DONG)
#GUIDE:  sudo apt update
#GUIDE:  sudo apt install -y curl git unzip xz-utils zip rsync libglu1-mesa clang cmake ninja-build pkgconf libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev build-essential
#GUIDE:  (libsecret-1-dev can cho flutter_secure_storage. Plugin khac co the can them thu vien -dev:
#GUIDE:   neu log bao "required packages were not found: ten>=x.y", cai goi ten-dev tuong ung.)
#GUIDE:  (Canh bao "Failed to connect to system scope bus" la vo hai, bo qua.)
#GUIDE:
#GUIDE:BUOC 4 - Cai Flutter ben trong Ubuntu (khong dung duoc Flutter cua Windows)
#GUIDE:  git clone https://github.com/flutter/flutter.git -b stable ~/flutter
#GUIDE:  echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.profile
#GUIDE:  source ~/.profile
#GUIDE:  flutter config --enable-linux-desktop
#GUIDE:  flutter doctor     (muc "Linux toolchain" phai co dau tich)
#GUIDE:
#GUIDE:BUOC 5 - Cai Rust (BAT BUOC neu du an dung libsql_dart / goi native Rust)
#GUIDE:  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
#GUIDE:  source ~/.cargo/env
#GUIDE:  echo '. "$HOME/.cargo/env"' >> ~/.profile
#GUIDE:  rustup default stable
#GUIDE:  rustup show active-toolchain     (phai in ra stable-x86_64-unknown-linux-gnu)
#GUIDE:
#GUIDE:BUOC 6 - Kiem tra tu Windows (cmd hoac PowerShell)
#GUIDE:  wsl -- bash -lc "flutter --version"
#GUIDE:  Neu in ra phien ban Flutter la xong. Neu bao "command not found" thi PATH o buoc 4
#GUIDE:  chua ghi vao ~/.profile.
#GUIDE:
#GUIDE:BUOC 7 - Chay lai build_app.bat, chon 8 (ban chay) hoac 9 (.deb).
#GUIDE:  Ket qua .deb: thu muc build\deb trong project.
#GUIDE:
#GUIDE:LUU Y
#GUIDE:  - File bat tu chep ma nguon sang ~/.wsl_build/<ten app> trong Ubuntu roi build o do
#GUIDE:    (build truc tiep tren o Windows /mnt/d se loi "Operation not permitted" cua CMake).
#GUIDE:    Ket qua duoc chep lai ve build\linux va build\deb trong project.
#GUIDE:  - Goi .deb la ban co ban: chua co icon. Cai thu tren Ubuntu: sudo apt install ./ten_goi.deb
#GUIDE:  - Nen dung phien ban Flutter gan giong ban tren Windows (xem: flutter --version).
#WXS:<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">
#WXS:  <Package Name="@APPNAME@" Manufacturer="@APPNAME@" Version="@APPVER@" UpgradeCode="@UPGRADE@" Scope="perMachine">
#WXS:    <MajorUpgrade DowngradeErrorMessage="Da cai phien ban moi hon." />
#WXS:    <MediaTemplate EmbedCab="yes" />
#WXS:    <StandardDirectory Id="ProgramFiles64Folder">
#WXS:      <Directory Id="INSTALLFOLDER" Name="@APPNAME@">
#WXS:        <Component Id="MainExeComponent" Bitness="always64">
#WXS:          <File Id="MainExe" Source="build\windows\x64\runner\Release\@APPNAME@.exe">
#WXS:            <Shortcut Id="StartMenuShortcut" Directory="ProgramMenuFolder" Name="@APPNAME@" WorkingDirectory="INSTALLFOLDER" />
#WXS:            <Shortcut Id="DesktopShortcut" Directory="DesktopFolder" Name="@APPNAME@" WorkingDirectory="INSTALLFOLDER" />
#WXS:          </File>
#WXS:        </Component>
#WXS:      </Directory>
#WXS:    </StandardDirectory>
#WXS:    <Feature Id="Main">
#WXS:      <ComponentRef Id="MainExeComponent" />
#WXS:      <ComponentGroupRef Id="AppFiles" />
#WXS:    </Feature>
#WXS:  </Package>
#WXS:</Wix>
#PS:param([string]$Src,[string]$Exe,[string]$Out)
#PS:$root = (Resolve-Path -LiteralPath $Src).Path.TrimEnd('\')
#PS:$skip = Join-Path $root $Exe
#PS:$sb = New-Object System.Text.StringBuilder
#PS:[void]$sb.AppendLine('<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs">')
#PS:[void]$sb.AppendLine('  <Fragment>')
#PS:[void]$sb.AppendLine('    <ComponentGroup Id="AppFiles" Directory="INSTALLFOLDER">')
#PS:$i = 0
#PS:Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.FullName -ne $skip } | ForEach-Object {
#PS:  $i++
#PS:  $rel = $_.FullName.Substring($root.Length + 1)
#PS:  $dir = Split-Path $rel -Parent
#PS:  $sub = ''
#PS:  if ($dir) { $sub = ' Subdirectory="' + [Security.SecurityElement]::Escape($dir) + '"' }
#PS:  $f = [Security.SecurityElement]::Escape($_.FullName)
#PS:  [void]$sb.AppendLine('      <Component Id="c' + $i + '" Bitness="always64"' + $sub + '><File Source="' + $f + '" /></Component>')
#PS:}
#PS:[void]$sb.AppendLine('    </ComponentGroup>')
#PS:[void]$sb.AppendLine('  </Fragment>')
#PS:[void]$sb.AppendLine('</Wix>')
#PS:[IO.File]::WriteAllText($Out, $sb.ToString())
#PS:Write-Host ('Da liet ke ' + $i + ' file de dong goi vao MSI.')
#PS:if ($i -lt 1) { Write-Host 'LOI: khong co file nao trong thu muc Release'; exit 1 }
