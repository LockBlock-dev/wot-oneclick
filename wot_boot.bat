@echo off
REM wot one-click boot: headless broker, settle, then game; all in ONE wine
REM session (shared WGCS_IPC pipe). Steam tracks via start /wait.
start "" "C:\ProgramData\Wargaming.net\GameCenter for Steam\wgc.exe" --target-game-folder "S:\steamapps\common\World of Tanks" -d "S:\steamapps\common\World of Tanks" --background
ping -n 45 127.0.0.1 >nul
start "" /wait "S:\steamapps\common\World of Tanks\eu\WorldOfTanks.exe"
