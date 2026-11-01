# wot-oneclick — one Steam click → hangar, no Play button

Launcher automation for the Steam build of World of Tanks EU. Steam still
launches the game (overlay, playtime and tracking intact); this only
replaces the _manual Play click_ with a scripted boot: headless WGC
broker → settle → game exe, all inside a single Proton/wine session so
the `WGCS_IPC` token pipe is shared. Login happens via the genuine
token2 SSO — no credentials stored, no traffic modified, no gameplay
touched.

## Files

- `wot-launch.sh` — Steam launch-options entry point (dispatcher).
  Default mode `oneclick`; see Modes below.
- `wot_boot.bat` — runs inside wine: starts the broker with
  `--background`, waits for its IPC server to come up (polls the broker's
  own log for `GameCenter initialization finished`, 45 s cap), then
  `start /wait`s the game exe via its `S:\…` path (the broker only
  accepts the game folder in that form).

Live copies live in `~/.local/bin/wot-oneclick/`; this directory is the
source of truth — edit here, copy out to deploy.

## Install

Steam → World of Tanks → Properties → Launch Options:

```
[PROTON ENV VARS] $HOME/.local/bin/wot-oneclick/wot-launch.sh %command%
```

(Keep your own env prefix, e.g. ProtonDB tuning like
`PROTON_NO_FSYNC=1`, `WINE_CPU_TOPOLOGY=…` — only the trailing
`<script> %command%` part matters.)
`%command%` substitution is what makes the rewire possible: Steam
expands it to its normal `proton … wgcs_api.exe` invocation and our
script receives that as arguments, inheriting the full Steam context
(container, `SteamGameId`, Steam client IPC, GPU env).

## Runtime sequence

1. Script ensures the `s:` drive symlink (`→ $HOME/.local/share/Steam`;
   Proton prunes it on some startups, WGC's `S:\…` paths need it).
2. Copies `wot_boot.bat` to `/tmp` so wine sees `Z:\tmp\wot_boot.bat`.
3. `exec`s a single `proton waitforexitandrun` on the batch → one
   wineserver → broker and game share the pipe namespace.
4. Broker onboards headless (Steam ticket → token2 tails, ~5–10 s).
5. Once the broker reports a finished initialization (~2.5 s) the game
   starts, `VerifyGameImported` sees the
   `S:\…` folder, pulls a tail, logs in. Hangar, zero clicks.
6. After account-done, `wgc.exe` may be killed (it leaks RAM under
   Proton/CEF); the game holds its session. Reconnect-after-drop is the
   one path that may want the broker back — supervisor respawn is
   planned, not yet implemented.

## Modes (`/tmp/wot_test` override, else `oneclick`)

- `oneclick` — production path above.
- `transparent` — log + exec the original Steam command (stock behavior).
- `wgc-noopen`, `wgc-background`, `game-sdirect`, `full-direct` —
  retired matrix experiments (two-proton split-brain, windowed broker).
  Kept for debugging; `game-sdirect`/`full-direct` are known-broken
  (separate wineservers can't share the pipe).

## Requirements / notes

- Steam build of WoT (WGC publication), Proton Experimental, verified
  against WoT EU 2.4.1.0, Oct 2026. `s:` mapping, `wgcs_api.exe`
  chain and token2 SSO are Steam-build specifics.
- The wait is a readiness poll, not a fixed sleep, because the game's
  WGC client does not retry: its first call must find
  `\\.\pipe\WgIpcPipe` or it bails out with the "relaunch via Steam"
  dialog (too-short costs a full restart). The broker logs
  `GameCenter initialization finished` ~2.3 s after its log starts and
  finishes Steam onboarding ~0.4 s later, so the batch polls for that
  marker plus a 3 s cushion — ~6 s from click to game instead of 45 s.
  The poll has to live inside the wine session (batch side) to preserve
  the single-wineserver pipe sharing. If the marker ever disappears
  from a future WGC log format the tick cap degrades to the old 45 s
  wait rather than hanging.
- If the game shows the "relaunch via Steam" dialog, the broker wasn't
  reachable (pipe split or dead) — check `wgc_*.log` for `8023` /
  `VerifyGameImported` lines.
- Fair-play: this automates launching with genuine credentials only.
  It does not alter game functionality; still, any third-party process
  around the client is used at your own risk.
