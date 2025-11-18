@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Video File Organizer (Windows .bat, robust timestamps) ===
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

    rem ---- pattern_full from entire timeslot (like .sh) ----
    rem Example: "1st quarter , 06:18 - 06:40"
    rem 1) " , " -> "_"
    rem 2) spaces -> "_"
    rem 3) ":"     -> "_"
    set "pattern_full=!timeslot!"
    set "pattern_full=!pattern_full: , =_!"
    set "pattern_full=!pattern_full: =_!"
    set "pattern_full=!pattern_full::=_!"

    rem ---- extract timerange and build time-only patterns ----
    rem split timeslot at comma: left = quarter, right = " 06:18 - 06:40"
    set "timerange="
    for /f "tokens=1* delims=," %%Q in ("!timeslot!") do (
      set "timerange=%%R"
    )

    rem clean " 06:18 - 06:40" -> "06:18-06:40"
    set "tr=!timerange!"
    set "tr=!tr: - =-!"

    rem split start/end around '-'
    set "start="
    set "end="
    for /f "tokens=1,2 delims=-" %%T in ("!tr!") do (
      set "start=%%T"
      set "end=%%U"
    )

    rem parse mm:ss for start/end (spaces and ':' as delimiters)
    set "sm=" & set "ss=" & set "em=" & set "es="
    for /f "tokens=1,2 delims= :" %%M in ("!start!") do (
      set "sm=%%M"
      set "ss=%%N"
    )
    for /f "tokens=1,2 delims= :" %%M in ("!end!") do (
      set "em=%%M"
      set "es=%%N"
    )

    rem time-only patterns
    set "pattern_time1="
    if not "!sm!"=="" if not "!ss!"=="" if not "!em!"=="" if not "!es!"=="" (
      set "pattern_time1=!sm!_!ss!_-_!em!_!es!"
    )

    rem same but without leading zeros on each component
    set "sm2=!sm!"
    set "ss2=!ss!"
    set "em2=!em!"
    set "es2=!es!"

    if defined sm2 if "!sm2:~0,1!"=="0" set "sm2=!sm2:~1!"
    if defined ss2 if "!ss2:~0,1!"=="0" set "ss2=!ss2:~1!"
    if defined em2 if "!em2:~0,1!"=="0" set "em2=!em2:~1!"
    if defined es2 if "!es2:~0,1!"=="0" set "es2=!es2:~1!"

    set "pattern_time2="
    if not "!sm2!"=="" if not "!ss2!"=="" if not "!em2!"=="" if not "!es2!"=="" (
      set "pattern_time2=!sm2!_!ss2!_-_!em2!_!es2!"
    )

    echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
    echo   pattern_full  : !pattern_full!
    if defined pattern_time1 echo   pattern_time1: !pattern_time1!
    if defined pattern_time2 echo   pattern_time2: !pattern_time2!

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

    rem ---- scan mp4 files and move matches ----
    set "foundAny="

    for /f "delims=" %%F in ('dir /b "*.mp4" 2^>nul') do (
      set "FNAME=%%F"
      set "hit="

      rem 1) match full timeslot pattern
      if defined pattern_full (
        echo "%%F" | find /I "!pattern_full!" >nul && set "hit=1"
      )

      rem 2) match time-only pattern with zeros
      if not defined hit if defined pattern_time1 (
        echo "%%F" | find /I "!pattern_time1!" >nul && set "hit=1"
      )

      rem 3) match time-only pattern without leading zeros
      if not defined hit if defined pattern_time2 (
        echo "%%F" | find /I "!pattern_time2!" >nul && set "hit=1"
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
