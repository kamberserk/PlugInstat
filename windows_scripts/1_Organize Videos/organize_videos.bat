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

rem === main loop: parse directly, no subroutines ===
for /f "usebackq tokens=1-3 delims=|" %%A in ("video_text.txt") do (
  set "id=%%A"
  set "timeslot=%%B"
  set "setplay=%%C"

  rem skip lines without a setplay name
  if not "!setplay!"=="" (

    rem ---- split timeslot by first comma to get the quarter part ----
    rem example timeslot: "1st quarter , 01:16 - 01:30"
    set "quarter_part="
    set "time_part="

    for /f "tokens=1* delims=," %%Q in ("!timeslot!") do (
      set "quarter_part=%%Q"
      set "time_part=%%R"
    )

    rem normalize quarter variants
    set "quarter_underscore=!quarter_part: =_!"
    set "quarter_no_space=!quarter_part: =!"

    rem normalize full timeslot to something filesystem-ish:
    rem   1) remove spaces
    rem   2) replace commas with underscores
    rem   3) replace colons with underscores
    rem   4) replace hyphens with _-_
    set "normalized_pattern=!timeslot!"
    set "normalized_pattern=!normalized_pattern: =!"
    set "normalized_pattern=!normalized_pattern:,=_!"
    set "normalized_pattern=!normalized_pattern::=_!"
    set "normalized_pattern=!normalized_pattern:-=_-_!"

    echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
    echo   Pattern (time): !normalized_pattern!
    echo   Quarter "_": !quarter_underscore!
    echo   Quarter "nospace": !quarter_no_space!

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

      rem check normalized full pattern
      if not "!normalized_pattern!"=="" (
        echo "%%F" | find /I "!normalized_pattern!" >nul && set "hit=1"
      )

      rem check quarter underscore
      if not defined hit if not "!quarter_underscore!"=="" (
        echo "%%F" | find /I "!quarter_underscore!" >nul && set "hit=1"
      )

      rem check quarter no-space
      if not defined hit if not "!quarter_no_space!"=="" (
        echo "%%F" | find /I "!quarter_no_space!" >nul && set "hit=1"
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
