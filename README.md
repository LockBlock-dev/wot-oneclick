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
  `--background`, waits 45 s, then `start /wait`s the game exe via its
  `S:\…` path (the broker only accepts the game folder in that form).

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
5. After the settle wait the game starts, `VerifyGameImported` sees the
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

- Steam build of WoT (WGC publication). `s:` mapping, `wgcs_api.exe`
  chain and token2 SSO are Steam-build specifics.
- The 45 s settle covers wine + broker boot with ~2× margin (broker
  itself is game-ready ~8 s after its log starts; too-short costs a full
  restart, too-long costs seconds). A readiness poll instead of a fixed
  sleep is future work — it has to live inside the wine session (batch
  side) to preserve the single-wineserver pipe sharing, so it stays
  dumb and robust for now.
- If the game shows the "relaunch via Steam" dialog, the broker wasn't
  reachable (pipe split or dead) — check `wgc_*.log` for `8023` /
  `VerifyGameImported` lines.
- Fair-play: this automates launching with genuine credentials only.
  It does not alter game functionality; still, any third-party process
  around the client is used at your own risk.
