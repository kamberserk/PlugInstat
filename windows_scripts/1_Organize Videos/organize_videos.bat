@echo off
setlocal EnableExtensions EnableDelayedExpansion

echo === Video File Organizer (pure CMD) ===
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

rem === main loop: each line -> call subroutine ===
for /f "usebackq delims=" %%L in ("video_text.txt") do (
  call :processLine "%%L"
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
exit /b 0


rem =================== process one line ===================
:processLine
setlocal EnableDelayedExpansion

set "line=%~1"
if "!line!"=="" (
  endlocal & goto :eof
)

rem id|timeslot|setplay
for /f "tokens=1-3 delims=|" %%A in ("!line!") do (
  set "id=%%~A"
  set "timeslot=%%~B"
  set "setplay=%%~C"
)

call :trim setplay setplay

if "!setplay!"=="" (
  echo Skipping (empty set play): !line!
  echo.
  endlocal & goto :eof
)

rem ---- split timeslot: "1st quarter , 01:16 - 01:30" ----
set "quarter_part="
set "time_part="

for /f "tokens=1* delims=," %%Q in ("!timeslot!") do (
  set "quarter_part=%%~Q"
  set "time_part=%%~R"
)
call :trim quarter_part quarter_part
call :trim time_part time_part

rem split time_part: "01:16 - 01:30"
set "start_raw="
set "end_raw="
for /f "tokens=1,2 delims=-" %%S in ("!time_part!") do (
  set "start_raw=%%~S"
  set "end_raw=%%~T"
)
call :trim start_raw start_raw
call :trim end_raw end_raw

rem split by colon to get mm:ss
set "sm=" & set "ss=" & set "em=" & set "es="
for /f "tokens=1,2 delims=:" %%M in ("!start_raw!") do (
  set "sm=%%~M"
  set "ss=%%~N"
)
for /f "tokens=1,2 delims=:" %%M in ("!end_raw!") do (
  set "em=%%~M"
  set "es=%%~N"
)

rem remove leading zeros (1*value trick)
if defined sm set /a sm=1*!sm! 2>nul
if defined ss set /a ss=1*!ss! 2>nul
if defined em set /a em=1*!em! 2>nul
if defined es set /a es=1*!es! 2>nul

set "normalized_pattern="
if defined sm if defined ss if defined em if defined es (
  set "normalized_pattern=!sm!_!ss!_-_!em!_!es!"
)

set "quarter_underscore=!quarter_part: =_!"
set "quarter_no_space=!quarter_part: =!"

echo ID=!id! ^| Timeslot=!timeslot! ^| SetPlay=!setplay!
if defined normalized_pattern (
  echo   Pattern (time): !normalized_pattern!
) else (
  echo   (No valid time pattern parsed)
)
echo   Quarter variants: "_": !quarter_underscore!   "nospace": !quarter_no_space!

rem ---- ensure destination folder exists ----
if not exist "!setplay!\" (
  mkdir "!setplay!" 2>nul
  if errorlevel 1 (
    echo   x Failed to create folder "!setplay!"
    set /a errors+=1
    echo.
    endlocal & goto :eof
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
  set "UP=!FNAME!"
  call :toUpper UP

  set "hit="

  if defined normalized_pattern (
    set "P1=!normalized_pattern!"
    call :toUpper P1
    call :contains "!UP!" "!P1!" hit
  )

  if "!hit!"=="" (
    set "P2=!quarter_underscore!"
    call :toUpper P2
    call :contains "!UP!" "!P2!" hit
  )

  if "!hit!"=="" (
    set "P3=!quarter_no_space!"
    call :toUpper P3
    call :contains "!UP!" "!P3!" hit
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
endlocal & goto :eof


rem =================== helpers ===================

:trim
rem Usage: call :trim sourceVar destVar
setlocal EnableDelayedExpansion
set "s=!%~1!"
for /f "tokens=* delims= " %%T in ("!s!") do set "s=%%T"
:trimLoop
if "!s:~-1!"==" " set "s=!s:~0,-1!" & goto :trimLoop
endlocal & set "%~2=%s%"
goto :eof

:toUpper
rem Usage: call :toUpper varName
setlocal EnableDelayedExpansion
set "s=!%~1!"
for %%A in (a=A b=B c=C d=D e=E f=F g=G h=H i=I j=J k=K l=L m=M n=N o=O p=P q=Q r=R s=S t=T u=U v=V w=W x=X y=Y z=Z) do set "s=!s:%%A=%%B!"
endlocal & set "%~1=%s%"
goto :eof

:contains
rem Usage: call :contains "HAYSTACK" "NEEDLE" outVar
setlocal EnableDelayedExpansion
set "H=%~1"
set "N=%~2"
set "o="
if not "!N!"=="" (
  set "tmp=!H:%~2=!"
  if not "!tmp!"=="!H!" set "o=1"
)
endlocal & set "%~3=%o%"
goto :eof
