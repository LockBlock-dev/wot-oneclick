@echo off
REM wot one-click boot: headless broker, wait for its IPC server, then the
REM game; all in ONE wine session (shared WGCS_IPC pipe). Steam tracks via
REM start /wait.
setlocal EnableExtensions

set "GCDIR=C:\ProgramData\Wargaming.net\GameCenter for Steam"
set "LOGDIR=%GCDIR%\logs"
set "GAMEEXE=S:\steamapps\common\World of Tanks\eu\WorldOfTanks.exe"

REM Remember the newest broker log so the wait below can tell this run's log
REM apart from a stale one left by a previous launch.
set "PREV="
for /f "delims=" %%F in ('dir /b /o-d "%LOGDIR%\wgc_*.log" 2^>nul') do if not defined PREV set "PREV=%%F"

start "" "%GCDIR%\wgc.exe" --target-game-folder "S:\steamapps\common\World of Tanks" -d "S:\steamapps\common\World of Tanks" --background

REM The game's WGC client does not wait for the broker: its first call must
REM find the \\.\pipe\WgIpcPipe instance or it bails out with the "relaunch
REM via Steam" dialog. So poll the broker's own log for a finished
REM initialization (~2.5 s) instead of sleeping a fixed 45 s. The tick cap
REM keeps the old worst case if that marker ever disappears from the log.
set /a TICKS=0
:wait
set "NEW="
for /f "delims=" %%F in ('dir /b /o-d "%LOGDIR%\wgc_*.log" 2^>nul') do if not defined NEW set "NEW=%%F"
if not defined NEW goto :tick
if "%NEW%"=="%PREV%" goto :tick
findstr /c:"GameCenter initialization finished" "%LOGDIR%\%NEW%" >nul 2>&1 && goto :ready
:tick
set /a TICKS+=1
if %TICKS% GEQ 45 goto :ready
ping -n 2 127.0.0.1 >nul
goto :wait

:ready
REM Cushion: the pipe server is up before that marker, but the broker still
REM finishes Steam onboarding (the token2 tail) right after it.
ping -n 4 127.0.0.1 >nul
start "" /wait "%GAMEEXE%"
