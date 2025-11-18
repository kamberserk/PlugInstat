@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Video File Organizer (timestamp-based, handles leading zeros) ===
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

    rem ---- split timeslot into quarter and time range ----
    rem Example: 1st quarter , 06:18 - 06:40
    set "quarter_part="
    set "time_part="

    for /f "tokens=1* delims=," %%Q in ("!timeslot!") do (
      set "quarter_part=%%Q"
      set "time_part=%%R"
    )

    rem if no time_part, skip
    if "!time_part!"=="" (
      echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
      echo   (No time range found, skipping)
      echo.
    ) else (

      rem ---- build base time pattern (zero-padded) from time_part ----
      rem Example time_part: " 06:18 - 06:40"
      rem 1) remove spaces -> "06:18-06:40"
      rem 2) replace ":" with "_" -> "06_18-06_40"
      rem 3) replace "-" with "_-_" -> "06_18_-_06_40"
      set "pattern_time_zpad=!time_part: =!"
      set "pattern_time_zpad=!pattern_time_zpad::=_!"
      set "pattern_time_zpad=!pattern_time_zpad:-=_-_!"

      rem ---- build non-zero-padded variant pattern_time_noz ----
      set "pattern_time_noz=!pattern_time_zpad!"
      set "pattern_time_noz=!pattern_time_noz:_01=_1!"
      set "pattern_time_noz=!pattern_time_noz:_02=_2!"
      set "pattern_time_noz=!pattern_time_noz:_03=_3!"
      set "pattern_time_noz=!pattern_time_noz:_04=_4!"
      set "pattern_time_noz=!pattern_time_noz:_05=_5!"
      set "pattern_time_noz=!pattern_time_noz:_06=_6!"
      set "pattern_time_noz=!pattern_time_noz:_07=_7!"
      set "pattern_time_noz=!pattern_time_noz:_08=_8!"
      set "pattern_time_noz=!pattern_time_noz:_09=_9!"

      echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
      echo   pattern_time_zpad: !pattern_time_zpad!
      echo   pattern_time_noz : !pattern_time_noz!

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

        rem 1) match time with leading zeros
        if not "!pattern_time_zpad!"=="" (
          echo "%%F" | find /I "!pattern_time_zpad!" >nul && set "hit=1"
        )

        rem 2) match time without leading zeros (06 -> 6, etc.)
        if not defined hit if not "!pattern_time_noz!"=="" (
          echo "%%F" | find /I "!pattern_time_noz!" >nul && set "hit=1"
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
)

echo === Summary ===
echo Folders created: %folders_created%
echo Files moved    : %files_moved%
echo Errors         : %errors%
echo.

endlocal
pause
exit /b 0
