#!/bin/bash
# wot-launch.sh — World of Tanks one-click Steam launcher.
#
# Steam launch options:
#   PROTON_NO_FSYNC=1 DISPLAY=:0 WINE_CPU_TOPOLOGY=8:0,1,2,3,4,5,6,7 ~/.local/bin/wot-oneclick/wot-launch.sh %command%
#
# What it does: instead of the WGC launcher UI, it boots a single wine
# session running Z:\tmp\wot_boot.bat equivalent inline: headless broker
# (--background, no window) -> 60 s settle -> game exe with /wait, so one
# Steam click lands in hangar via token2 SSO, no Play click. Steam tracks
# the session (overlay, playtime) because this script execs proton last.
#
# Exit paths: game exit code propagates (exec). Kill wgc.exe after
# account-done to dodge its RAM leak (see T3 notes in session log).
#
# Override: create /tmp/wot_test containing one of:
#   transparent  - log + exec original Steam command unchanged
#   wgc-noopen / wgc-background / game-sdirect / full-direct (legacy tests)

LOG=/tmp/wot_steam_launch.log
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODE="oneclick"
[ -f /tmp/wot_test ] && MODE=$(head -n 1 /tmp/wot_test | tr -d ' \r\n')
[ -z "$MODE" ] && MODE="transparent"

# proton script = argv element ending in /proton
PROTON=""
for a in "$@"; do
  case "$a" in
    */proton) PROTON="$a" ;;
  esac
done
GAMEROOT="$HOME/.local/share/Steam/steamapps/common/World of Tanks"
GCDIR="$HOME/.local/share/Steam/steamapps/compatdata/1407200/pfx/drive_c/ProgramData/Wargaming.net/GameCenter for Steam"
BAT="$HERE/wot_boot.bat"

log() { echo "$@" >> "$LOG" 2>&1; }

# The .bat must be visible to wine as Z:\tmp\<name>. Prefer the permanent
# copy next to this script; fall back to /tmp legacy copy.
BAT_UNIX="$BAT"
[ -f "$BAT_UNIX" ] || BAT_UNIX="/tmp/wot_boot.bat"
BAT_WIN="Z:\\tmp\\$(basename "$BAT_UNIX")"
if [ "$BAT_UNIX" != "/tmp/$(basename "$BAT_UNIX")" ]; then
  cp -f "$BAT_UNIX" "/tmp/$(basename "$BAT_UNIX")" 2>/dev/null
fi

case "$MODE" in
  oneclick)
    # Production: single proton session, batchfile boot, game on real :0.
    log "MODE=oneclick"
    PFX="$HOME/.local/share/Steam/steamapps/compatdata/1407200/pfx"
    ln -sfn "$HOME/.local/share/Steam" "$PFX/dosdevices/s:" 2>/dev/null
    export DISPLAY=:0
    cd "$GAMEROOT/eu" || exit 9
    exec "$PROTON" waitforexitandrun "$BAT_WIN" >> /tmp/wot_dispatch.log 2>&1
    ;;
  wgc-noopen)
    log "MODE=wgc-noopen"
    export DISPLAY=:99
    cd "$GCDIR" || exit 9
    exec "$PROTON" run ./wgc.exe \
      --target-game-folder "S:\steamapps\common\World of Tanks" \
      -d "S:\steamapps\common\World of Tanks" \
      >> /tmp/wot_dispatch.log 2>&1
    ;;
  wgc-background)
    log "MODE=wgc-background"
    export DISPLAY=:99
    cd "$GCDIR" || exit 9
    exec "$PROTON" run ./wgc.exe \
      --target-game-folder "S:\steamapps\common\World of Tanks" \
      -d "S:\steamapps\common\World of Tanks" \
      --background \
      >> /tmp/wot_dispatch.log 2>&1
    ;;
  game-sdirect)
    log "MODE=game-sdirect"
    PFX="$HOME/.local/share/Steam/steamapps/compatdata/1407200/pfx"
    ln -sfn "$HOME/.local/share/Steam" "$PFX/dosdevices/s:" 2>/dev/null
    export DISPLAY=:0
    cd "$PFX/dosdevices/s:/steamapps/common/World of Tanks/eu" || exit 9
    log "cwd=$(pwd)"
    exec "$PROTON" waitforexitandrun ./WorldOfTanks.exe \
      >> /tmp/wot_dispatch.log 2>&1
    ;;
  full-direct)
    log "MODE=full-direct"
    PFX="$HOME/.local/share/Steam/steamapps/compatdata/1407200/pfx"
    ln -sfn "$HOME/.local/share/Steam" "$PFX/dosdevices/s:" 2>/dev/null
    export DISPLAY=:99
    cd "$GCDIR" || exit 9
    "$PROTON" run ./wgc.exe \
      --target-game-folder "S:\steamapps\common\World of Tanks" \
      -d "S:\steamapps\common\World of Tanks" \
      --background \
      >> /tmp/wot_dispatch.log 2>&1 &
    WBROKER=$!
    log "broker pid=$WBROKER, waiting 60s for pipe"
    sleep 60
    export DISPLAY=:0
    cd "$GAMEROOT/eu" || exit 9
    log "launching game via S: path"
    exec "$PROTON" waitforexitandrun 'S:\steamapps\common\World of Tanks\eu\WorldOfTanks.exe' \
      >> /tmp/wot_dispatch.log 2>&1
    ;;
  *)
    log "MODE=transparent argc=$#"
    exec "$@"
    ;;
esac
