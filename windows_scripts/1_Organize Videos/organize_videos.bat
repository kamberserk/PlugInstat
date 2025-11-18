@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Video File Organizer (CMD) ===
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

rem === main loop: parse each line directly ===
for /f "usebackq tokens=1-3 delims=|" %%A in ("video_text.txt") do (
  set "id=%%A"
  set "timeslot=%%B"
  set "setplay=%%C"

  rem Skip if setplay is empty
  if not "%%C"=="" (

    rem ---- split timeslot into quarter and time range ----
    rem Example: 1st quarter , 14:19 - 14:46
    set "quarter="
    set "timerange="

    for /f "tokens=1* delims=," %%Q in ("%%B") do (
      set "quarter=%%Q"
      set "timerange=%%R"
    )

    rem quarter patterns for matching
    set "quarter_underscore=!quarter: =_!"
    set "quarter_nospace=!quarter: =!"

    rem ---- parse timerange " 14:19 - 14:46" into sm ss em es ----
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

    rem original zero-padded pattern (as in text file)
    set "pattern1="
    if not "!sm!"=="" if not "!ss!"=="" if not "!em!"=="" if not "!es!"=="" (
      set "pattern1=!sm!_!ss!_-_!em!_!es!"
    )

    rem trimmed leading zeros pattern (for filenames like 1_16_-_1_30)
    set "sm2=!sm!"
    set "ss2=!ss!"
    set "em2=!em!"
    set "es2=!es!"
    if defined sm2 if "!sm2:~0,1!"=="0" set "sm2=!sm2:~1!"
    if defined ss2 if "!ss2:~0,1!"=="0" set "ss2=!ss2:~1!"
    if defined em2 if "!em2:~0,1!"=="0" set "em2=!em2:~1!"
    if defined es2 if "!es2:~0,1!"=="0" set "es2=!es2:~1!"

    set "pattern2="
    if not "!sm2!"=="" if not "!ss2!"=="" if not "!em2!"=="" if not "!es2!"=="" (
      set "pattern2=!sm2!_!ss2!_-_!em2!_!es2!"
    )

    echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
    if defined pattern1 (
      echo   Time pattern1: !pattern1!
    ) else (
      echo   Time pattern1: (not parsed)
    )
    if defined pattern2 (
      echo   Time pattern2: !pattern2!
    ) else (
      echo   Time pattern2: (not parsed / same as p1)
    )
    echo   Quarter "_": !quarter_underscore!
    echo   Quarter ns: !quarter_nospace!

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

      if defined pattern1 (
        echo "%%F" | find /I "!pattern1!" >nul && set "hit=1"
      )

      if not defined hit if defined pattern2 (
        echo "%%F" | find /I "!pattern2!" >nul && set "hit=1"
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
