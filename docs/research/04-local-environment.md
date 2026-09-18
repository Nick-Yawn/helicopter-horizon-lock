# 04 – Local environment (checked 2026-09-18)

Read-only inspection of this PC, to tailor the setup checklist.

## Installed

| Item | Status | Location / detail |
|------|--------|-------------------|
| Arma 3 | Installed, version 2.22 (build 24951143) | `B:\SteamLibrary\steamapps\common\Arma 3` |
| Arma 3 Tools | Installed | `B:\SteamLibrary\steamapps\common\Arma 3 Tools` (AddonBuilder, DSSignFile with DSCreateKey/DSSignFile/DSCheckSignatures, Publisher, Binarize, CfgConvert, BankRev, ObjectBuilder, TexView2, WorkDrive) |
| CBA_A3 (Workshop 450814997) | **Not subscribed** | Needed as the mod's dependency for settings + keybinds |
| HEMTT | **Not installed** | `winget` is available for installing it |
| git | Installed | Git for Windows (mingw64) |
| Python 3.12 | Installed | user-local install |
| cargo / scoop | Not installed | not needed if HEMTT comes via winget or a release binary |

## Workshop subscriptions of note

- `@GCam Cinematic Camera Tool` (909893746) is linked in `!Workshop`. It is one of the
  cinematic camera scripts catalogued in 02-prior-art.md (sleep-loop based, stutters in
  vehicles). Useful as a quick in-game comparison, not as a base.
- Several "Pilot <helicopter> On Missions" mods (AH-99, Ghost Hawk, AH-9, MH-6) and
  Ryan's Zombies & Demons. No CBA, no ACE.
- 35 workshop items in total; most have no mod.cpp (missions/scenarios or compositions).

## Profile / logs

- Profile folder: `C:\Users\Nicho\Documents\Arma 3` (profile name `Nicho`), plus
  other profiles `Nick` and `Nick_Yawn`.
- RPT logs: `C:\Users\Nicho\AppData\Local\Arma 3\Arma3_x64_*.rpt`. Most recent run
  seen: 2025-08-22.

## Implications for the checklist

1. Subscribe to CBA_A3 on the Workshop before first test.
2. Install HEMTT (winget, or GitHub release binary on PATH).
3. Arma 3 Tools is already present, so DSCreateKey / DSSignFile / Publisher are
   available for signing and Workshop upload without extra downloads.
4. Launch for testing from the B: install; `hemtt launch` needs to find that path
   (it reads the Steam library folders, verify in 03-tooling-and-structure.md).
