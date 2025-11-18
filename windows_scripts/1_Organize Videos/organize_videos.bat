@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Video File Organizer (simple CMD) ===
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

rem === main loop: parse each line directly, NO labels, NO call ===
for /f "usebackq tokens=1-3 delims=|" %%A in ("video_text.txt") do (
  set "id=%%A"
  set "timeslot=%%B"
  set "setplay=%%C"

  rem Skip if setplay is empty
  if not "%%C"=="" (

    rem ---- split timeslot into quarter and time range ----
    rem Example: 1st quarter , 01:16 - 01:30
    set "quarter="
    set "timerange="

    for /f "tokens=1* delims=," %%Q in ("%%B") do (
      set "quarter=%%Q"
      set "timerange=%%R"
    )

    rem quarter text as-is (used for matching)
    set "quarter_pattern=!quarter!"

    rem ---- parse timerange " 01:16 - 01:30" into mm ss mm ss ----
    rem delimiters: space, colon, hyphen
    set "sm="
    set "ss="
    set "em="
    set "es="

    for /f "tokens=1,2,3,4 delims=: -" %%H in ("!timerange!") do (
      set "sm=%%H"
      set "ss=%%I"
      set "em=%%J"
      set "es=%%K"
    )

    rem Build time pattern 01_16_-_01_30 (no colon substitutions)
    set "pattern="
    if not "!sm!"=="" if not "!ss!"=="" if not "!em!"=="" if not "!es!"=="" (
      set "pattern=!sm!_!ss!_-_!em!_!es!"
    )

    echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
    if defined pattern (
      echo   Time pattern : !pattern!
    ) else (
      echo   Time pattern : (not parsed)
    )
    echo   Quarter text : !quarter_pattern!

    rem ---- ensure destination folder exists ----
    if not exist "!setplay!" (
      mkdir "!setplay!" 2>nul
      if errorlevel 1 (
        echo   [ERROR] cannot create "!setplay!"
        set /a errors+=1
      ) else (
        echo   + Created folder "!setplay!"
        set /a folders_created+=1
      )
    ) else (
      echo   = Folder exists: "!setplay!"
    )

    rem ---- scan mp4 files and move matches ----
    set "foundAny="

    for /f "delims=" %%F in ('dir /b "*.mp4" 2^>nul') do (
      set "FNAME=%%F"
      set "hit="

      if defined pattern (
        echo "%%F" | find /I "!pattern!" >nul && set "hit=1"
      )

      if not defined hit if not "!quarter_pattern!"=="" (
        echo "%%F" | find /I "!quarter_pattern!" >nul && set "hit=1"
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
