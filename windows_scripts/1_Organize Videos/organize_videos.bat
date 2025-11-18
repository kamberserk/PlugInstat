@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Video File Organizer (Windows .bat, time-based only) ===
echo.

rem --- verify inputs ---
if not exist "video_text.txt" (
  echo Error: video_text.txt not found in current directory.
  pause
  exit /b 1
)

set "mp4_count=0"
for /f %%C in ('dir /b *.mp4 2^>nul ^| find /c /v ""') do set "mp4_count=%%C"
if "%mp4_count%"=="0" (
  echo Warning: No MP4 files in current directory. Folders may still be created.
  echo.
)

set /a folders_created=0
set /a files_moved=0
set /a errors=0

echo Processing video_text.txt...
echo.

rem === main loop: id|timeslot|setplay ===
for /f "usebackq tokens=1-3 delims=|" %%A in ("video_text.txt") do (
  set "id=%%A"
  set "timeslot=%%B"
  set "setplay=%%C"

  rem skip lines without a setplay name
  if not "!setplay!"=="" (

    rem ---- build pattern from full timeslot (like in .sh) ----
    rem Example: "1st quarter , 14:19 - 14:46"
    rem 1) " , " -> "_"
    rem 2) spaces -> "_"
    rem 3) ":"     -> "_"
    set "pattern=!timeslot!"
    set "pattern=!pattern: , =_!"
    set "pattern=!pattern: =_!"
    set "pattern=!pattern::=_!"

    echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
    echo   Pattern from timeslot: !pattern!

    rem ---- ensure destination folder exists ----
    if not exist "!setplay!" (
      mkdir "!setplay!" 2>nul
      if errorlevel 1 (
        echo   [ERROR] cannot create folder "!setplay!"
        set /a errors+=1
      ) else (
        echo   + Created folder "!setplay!"
        set /a folders_created+=1
      )
    ) else (
      echo   = Folder exists: "!setplay!"
    )

    rem ---- scan mp4 files and move matches (time-based only) ----
    set "foundAny="

    for /f "delims=" %%F in ('dir /b "*.mp4" 2^>nul') do (
      set "FNAME=%%F"
      set "hit="

      if not "!pattern!"=="" (
        echo "%%F" | find /I "!pattern!" >nul && set "hit=1"
      )

      if defined hit (
        if exist "%%F" (
          echo     -> moving "%%F" to "!setplay!\"
          move /y "%%F" "!setplay!\">nul
          if errorlevel 1 (
            echo        [ERROR] failed to move "%%F"
            set /a errors+=1
          ) else (
            set /a files_moved+=1
            set "foundAny=1"
          )
        )
      )
    )

    if not defined foundAny (
      echo   (No MP4 file matched this line)
    )

    echo.
  )
)

echo === Summary ===
echo Folders created: %folders_created%
echo Files moved    : %files_moved%
echo Errors         : %errors%
echo.

endlocal
pause
exit /b 0
