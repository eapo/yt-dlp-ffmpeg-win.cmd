@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

REM CONFIG
set "ROOT=%~dp0"
set "TOOLS=%ROOT%tools\"
set "YTDLP_URL=https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"

REM ---------------------------------------------------------------------------
REM OPTIONAL: override output directory via first argument
REM ---------------------------------------------------------------------------
if "%~1"=="" goto :EOF
echo "Output to:" %~1

set "ARG_OUT=%~1"
for %%i in ("%ARG_OUT%") do set "ARG_OUT=%%~fi"

if "%ARG_OUT%"=="" goto :EOF

if not exist "%ARG_OUT%" mkdir "%ARG_OUT%"
if not exist "%ARG_OUT%" (
    call :UI_ERR "Could not create directory: %ARG_OUT%"
    pause
)

set "OUT=%ARG_OUT%"

call :RESOLVE_DOWNLOADS

REM UI
for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "PATH=%TOOLS%;%PATH%"
call :RESOLVE_FFMPEG
call :SHOW_HEADER

REM ---------------------------------------------------------------------------
REM SESSION_LOOP
REM ---------------------------------------------------------------------------
:SESSION_LOOP
set "VID_URL="
set /p "VID_URL=YouTube URL (Q=quit): "
if /i "!VID_URL!"=="Q" exit /b 0
if "!VID_URL!"=="" (
    call :UI_ERR "URL cannot be empty."
    goto SESSION_LOOP
)

call :ENSURE_YTDLP
if errorlevel 1 goto SESSION_LOOP

:FORMAT_LOOP
call :SHOW_FORMATS
if errorlevel 1 goto SESSION_LOOP

call :ASK_FORMAT
if errorlevel 2 goto SESSION_LOOP
if errorlevel 1 goto FORMAT_LOOP

call :ENSURE_FFMPEG
if errorlevel 1 goto SESSION_LOOP

call :DO_DOWNLOAD
call :AFTER_MENU
if errorlevel 99 exit /b 0
goto SESSION_LOOP

goto :EOF

REM ---------------------------------------------------------------------------
REM SHOW_HEADER - one-line banner (ASCII + ANSI; UTF-8 safe in Windows Terminal)
REM ---------------------------------------------------------------------------
:SHOW_HEADER
echo.
powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false);$h=[char]0x256D+[char]0x2500+' eapo''s yt-dlp-ffmpeg-win.cmd v1 '+[char]0x2500+[char]0x2500+[char]0x2500+[char]0x254C+[char]0x254C+[char]0x2504+[char]0x2504;Write-Host $h -ForegroundColor Cyan"
echo.
exit /b 0

REM ---------------------------------------------------------------------------
REM SHOW_FORMATS
REM ---------------------------------------------------------------------------
:SHOW_FORMATS
echo.
echo %ESC%[96m  Available formats for:%ESC%[0m !VID_URL!
echo.
"%TOOLS%yt-dlp.exe" --js-runtimes node --no-update -F "!VID_URL!"
if errorlevel 1 (
    call :UI_ERR "Could not list formats."
    exit /b 1
)
echo.
exit /b 0

REM ---------------------------------------------------------------------------
REM ASK_FORMAT  (0=ok  1=retry  2=back to URL)
REM ---------------------------------------------------------------------------
:ASK_FORMAT
set "FMT_ID="
set "MERGE_DL=0"
echo.
echo   %ESC%[93m[A]%ESC%[0m Best audio   %ESC%[93m[V]%ESC%[0m Best video+audio   %ESC%[93m[M]%ESC%[0m Merge video+audio
echo   %ESC%[93m[C]%ESC%[0m Custom ID   %ESC%[93m[Q]%ESC%[0m Back to URL
set "PICK=V"
set /p "PICK=Format [Enter=V]: "
if "!PICK!"=="" set "PICK=V"
if /i "!PICK!"=="Q" exit /b 2
if /i "!PICK!"=="A" (
    set "FMT_ID=ba"
    set "MERGE_DL=0"
    exit /b 0
)
if /i "!PICK!"=="V" (
    set "FMT_ID=bv*+ba/b"
    set "MERGE_DL=0"
    exit /b 0
)
if /i "!PICK!"=="M" (
    call :ASK_MERGE
    exit /b !errorlevel!
)
if /i "!PICK!"=="C" (
    set /p "FMT_ID=  Enter format ID(s), e.g. 140 or 137+140: "
    if "!FMT_ID!"=="" (
        call :UI_ERR "No format ID entered."
        exit /b 1
    )
    set "MERGE_DL=0"
    exit /b 0
)
call :UI_ERR "Invalid choice. Use A, V, M, C, or Q."
exit /b 1

REM ---------------------------------------------------------------------------
REM ASK_MERGE - pick video-only and audio-only IDs; ffmpeg merges to one file
REM ---------------------------------------------------------------------------
:ASK_MERGE
set "MERGE_DL=1"
echo %ESC%[93m  Pick video-only and audio-only IDs from the list above.%ESC%[0m
set /p "VID_FMT=  Video format ID: "
set /p "AUD_FMT=  Audio format ID: "
if "!VID_FMT!"=="" (
    call :UI_ERR "Video format ID required."
    exit /b 1
)
if "!AUD_FMT!"=="" (
    call :UI_ERR "Audio format ID required."
    exit /b 1
)
set "FMT_ID=!VID_FMT!+!AUD_FMT!"
echo %ESC%[96m  Will merge: !FMT_ID! -^> mp4%ESC%[0m
exit /b 0

REM ---------------------------------------------------------------------------
REM DO_DOWNLOAD
REM ---------------------------------------------------------------------------
:DO_DOWNLOAD
if not exist "%OUT%" mkdir "%OUT%"
echo.
if "!MERGE_DL!"=="1" (
    echo %ESC%[96m  Downloading and merging !FMT_ID! to mp4 ...%ESC%[0m
) else (
    echo %ESC%[96m  Downloading format !FMT_ID! ...%ESC%[0m
)
echo.
if "!MERGE_DL!"=="1" (
    "%TOOLS%yt-dlp.exe" --no-update --ffmpeg-location "!FFMPEG_LOC!" -f "!FMT_ID!" --merge-output-format mp4 -P "!OUT!" -o "%%(title).200s [%%(id)s].%%(ext)s" "!VID_URL!"
) else (
    "%TOOLS%yt-dlp.exe" --no-update --ffmpeg-location "!FFMPEG_LOC!" -f "!FMT_ID!" -P "!OUT!" -o "%%(title).200s [%%(id)s].%%(ext)s" "!VID_URL!"
)
if errorlevel 1 (
    call :UI_ERR "DOWNLOAD FAILED."
) else (
    call :UI_OK "DOWNLOAD OK"
)
exit /b 0

REM ---------------------------------------------------------------------------
REM SHOW_MENU_FRAME - bottom border before post-download menu
REM ---------------------------------------------------------------------------
:SHOW_MENU_FRAME
powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false);$f=[char]0x2570+(-join(1..37|%%{[char]0x2500}))+[char]0x254C+[char]0x254C+[char]0x2504+[char]0x2504;Write-Host $f -ForegroundColor Cyan"
exit /b 0

REM ---------------------------------------------------------------------------
REM AFTER_MENU
REM ---------------------------------------------------------------------------
:AFTER_MENU
call :SHOW_MENU_FRAME
:MENU_LOOP
echo.
echo   %ESC%[96m[U]%ESC%[0m Update yt-dlp   %ESC%[96m[D]%ESC%[0m Another URL   %ESC%[96m[S]%ESC%[0m Source   %ESC%[96m[F]%ESC%[0m Folder   %ESC%[96m[Q]%ESC%[0m Quit
call :SHOW_SELECT_PROMPT
if /i "!PICK!"=="Q" exit /b 99
if /i "!PICK!"=="D" exit /b 0
if /i "!PICK!"=="U" (
    call :UPGRADE_YTDLP
    goto MENU_LOOP
)
if /i "!PICK!"=="S" (
    if exist "%ROOT%README.md" (
        start "" "%ROOT%README.md"
    ) else (
        call :UI_ERR "README.md not found."
    )
    goto MENU_LOOP
)
if /i "!PICK!"=="F" (
    if not exist "%OUT%" mkdir "%OUT%"
    explorer "%OUT%"
    goto MENU_LOOP
)
call :UI_ERR "Invalid choice. Use U, D, S, F, or Q."
goto MENU_LOOP

REM ---------------------------------------------------------------------------
REM ENSURE_YTDLP
REM ---------------------------------------------------------------------------
:ENSURE_YTDLP
if exist "%TOOLS%yt-dlp.exe" exit /b 0
if not exist "%TOOLS%" mkdir "%TOOLS%"
echo %ESC%[93m  First run - fetching yt-dlp...%ESC%[0m
curl -fsSL -o "%TOOLS%yt-dlp.exe" "%YTDLP_URL%"
if errorlevel 1 (
    call :UI_ERR "yt-dlp download failed."
    exit /b 1
)
exit /b 0

REM ---------------------------------------------------------------------------
REM ENSURE_FFMPEG
REM ---------------------------------------------------------------------------
:ENSURE_FFMPEG
call :RESOLVE_FFMPEG
if not "!FFMPEG_LOC!"=="" exit /b 0
call :UI_ERR "ffmpeg not found. Install ffmpeg or add it to PATH."
exit /b 1

REM ---------------------------------------------------------------------------
REM UPGRADE_YTDLP
REM ---------------------------------------------------------------------------
:UPGRADE_YTDLP
if not exist "%TOOLS%yt-dlp.exe" (
    call :UI_ERR "yt-dlp not installed yet."
    exit /b 0
)
echo %ESC%[93m  Updating yt-dlp...%ESC%[0m
"%TOOLS%yt-dlp.exe" -U
call :UI_OK "Update done."
exit /b 0

REM ---------------------------------------------------------------------------
REM RESOLVE_DOWNLOADS
REM ---------------------------------------------------------------------------
:RESOLVE_DOWNLOADS
REM set "OUT="
set "RawPath="
set "GUID={374DE290-123F-4565-9164-39C4925E467B}"
for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" /v "%GUID%" 2^>nul') do set "RawPath=%%b"
if not defined RawPath (
    for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" /v "%GUID%" 2^>nul') do set "RawPath=%%b"
)
if defined RawPath (
    for %%i in ("!RawPath!") do set "OUT=%%~fi\NewPipe"
)
if not defined OUT set "OUT=%USERPROFILE%\Downloads\NewPipe"
exit /b 0

REM ---------------------------------------------------------------------------
REM RESOLVE_FFMPEG
REM ---------------------------------------------------------------------------
:RESOLVE_FFMPEG
set "FFMPEG_LOC="
if exist "%TOOLS%ffmpeg.exe" (
    set "FFMPEG_LOC=%TOOLS%"
    goto STRIP_BS
)
for /f "delims=" %%F in ('where ffmpeg 2^>nul') do (
    set "FFMPEG_LOC=%%~dpF"
    goto STRIP_BS
)
exit /b 0

:STRIP_BS
if "!FFMPEG_LOC:~-1!"=="\" set "FFMPEG_LOC=!FFMPEG_LOC:~0,-1!"
exit /b 0

REM ---------------------------------------------------------------------------
REM SHOW_SELECT_PROMPT - UTF-8 prefix via PowerShell (same as header)
REM ---------------------------------------------------------------------------
:SHOW_SELECT_PROMPT
set "PICK=Q"
powershell -NoProfile -Command "[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false);[Console]::Write([string][char]0x2726+[char]0x2758+' Select [Enter=Q]: ')"
set /p "PICK="
if "!PICK!"=="" set "PICK=Q"
exit /b 0

REM ---------------------------------------------------------------------------
REM UI helpers
REM ---------------------------------------------------------------------------
:UI_OK
echo %ESC%[92m  * %~1%ESC%[0m
exit /b 0

:UI_ERR
echo %ESC%[91m  * %~1%ESC%[0m
exit /b 0
