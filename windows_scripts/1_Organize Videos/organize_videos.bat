@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Video File Organizer (pure CMD, no labels) ===
echo.

rem --- verify inputs ---
if not exist "video_text.txt" (
  echo Error: video_text.txt not found in current directory.
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

rem === main loop: parse each line directly ===
for /f "usebackq tokens=1-3 delims=|" %%A in ("video_text.txt") do (
  set "id=%%A"
  set "timeslot=%%B"
  set "setplay=%%C"

  rem Skip if setplay is empty
  if not "%%C"=="" (

    rem ---- split timeslot into quarter and time range ----
    rem Example timeslot: 1st quarter , 01:16 - 01:30
    set "quarter="
    set "timerange="

    for /f "tokens=1* delims=," %%D in ("%%B") do (
      set "quarter=%%D"
      set "timerange=%%E"
    )

    rem quarter variants for matching filenames
    set "quarter_underscore=!quarter: =_!"
    set "quarter_nospace=!quarter: =!"

    rem ---- parse timerange " 01:16 - 01:30" into mm ss mm ss ----
    rem delimiters: space, colon, hyphen
    set "pattern="
    for /f "tokens=1,2,3,4 delims=: -" %%H in ("!timerange!") do (
      set "sm=%%H"
      set "ss=%%I"
      set "em=%%J"
      set "es=%%K"
    )

    rem remove any leading zeros by simple arithmetic (if numeric)
    if defined sm set /a sm=1!sm! - 0 >nul 2>nul
    if defined ss set /a ss=1!ss! - 0 >nul 2>nul
    if defined em set /a em=1!em! - 0 >nul 2>nul
    if defined es set /a es=1!es! - 0 >nul 2>nul

    rem if they became empty or non-numeric, leave as-is
    if defined sm if defined ss if defined em if defined es (
      set "pattern=!sm!_!ss!_-_!em!_!es!"
    )

    echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
    if defined pattern (
      echo   Time pattern : !pattern!
    ) else (
      echo   Time pattern : (not parsed from "!timeslot!")
    )
    echo   Quarter "_"   : !quarter_underscore!
    echo   Quarter nospc: !quarter_nospace!

    rem ---- ensure destination folder exists ----
    if not exist "!setplay!\" (
      mkdir "!setplay!" 2>nul
      if errorlevel 1 (
        echo   x Failed to create folder "!setplay!"
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

      if not defined hit if not "!quarter_underscore!"=="" (
        echo "%%F" | find /I "!quarter_underscore!" >nul && set "hit=1"
      )

      if not defined hit if not "!quarter_nospace!"=="" (
        echo "%%F" | find /I "!quarter_nospace!" >nul && set "hit=1"
      )

      if defined hit (
        if exist "%%F" (
          echo     -> moving "%%F" to "!setplay!\"
          move /y "%%F" "!setplay!\">nul
          if errorlevel 1 (
            echo        x Failed to move "%%F"
            set /a errors+=1
          ) else (
            set /a files_moved+=1
            set "foundAny=1"
          )
        )
      )
    )

    if not defined foundAny (
      echo   (No MP4 file matched the patterns for this line)
    )

    echo.
  )
)

echo === Summary ===
echo Folders created: %folders_created%
echo Files moved    : %files_moved%
if %errors% gtr 0 echo Errors         : %errors%
echo.

echo Current folders:
for /f "delims=" %%D in ('dir /ad /b ^| sort') do echo   %%D

echo.
echo Files in each folder:
for /d %%D in (*) do (
  set "folder=%%~nxD"
  for /f %%C in ('dir /b "%%D\*.mp4" 2^>nul ^| find /c /v ""') do set "count=%%C"
  echo   !folder!/: !count! MP4 files
  if not "!count!"=="0" (
    for /f "delims=" %%M in ('dir /b "%%D\*.mp4" 2^>nul') do echo     %%M
  )
)

echo.
echo Done.
endlocal
exit /b 0
