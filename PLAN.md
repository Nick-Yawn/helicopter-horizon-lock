# Plan: packaging and release of Helicopter Horizon Lock

Rewritten 2026-09-18, after the feel runs; decisions taken the same day are recorded at
the end. The history is in `tests/feasibility/RESULTS.md` (in-game evidence) and `docs/research/`
(the research verdict).

## What we are shipping

An Arma 3 client-side addon that keeps the helicopter pilot's first-person view level with
the horizon by acting as the engine's FreeTrack head tracker. Per axis
`head = -clamp(a, -L, +L)`, yaw untouched. Two mod-shipped DLLs, no external program.
Settled in flight: no knee by default (crossing the knee causes nausea), full strength,
no washout, no smoothing, one button toggles between levelled and vanilla view.

Name: **Helicopter Horizon Lock**. "Horizon lock" is the action-camera term for a picture
that stays level while the body tilts, which is exactly this. Workshop title
"Helicopter Horizon Lock - Level First-Person Pilot View". Prefix `hhl` throughout
(folder `@HelicopterHorizonLock`, `hhl_main.pbo`, `hhl.bikey`, `hhl_x64.dll`,
`"hhl" callExtension`), renamed from `hzc` before anything is built.

## Distribution: Steam Workshop first, GitHub alongside

**Steam Workshop** is the primary channel. Every Arma 3 player installs mods through the
Launcher, updates are automatic, and the dependency on CBA_A3 is declared on the page.
Mods that ship DLLs are normal there (ACE3, TFAR, ACRE2, Intercept).

**GitHub** (public repo, releases with a zip) alongside, for three reasons that matter to
this mod in particular: the DLL sources are public and the build is reproducible, the
BattlEye submission can link to a release, and players who avoid the Workshop (or run
servers) get a plain zip. The Workshop page links to the repo; the repo README is the
Workshop description.

Not worth it: Armaholic is gone, withSIX is gone, ModDB has no Arma audience left.

Publishing tool: `hemtt publish` (creates or updates the Workshop item, uploads the release
build, sets the description from a file, appends the changelog). Arma 3 Tools' Publisher is
already installed as a fallback. First upload goes out hidden or friends-only for a test
subscribe, then public.

### BattlEye

The Launcher starts Arma with BattlEye by default, even for single player, and BattlEye
blocks any DLL it does not know (seen in run 4). Both DLLs need whitelisting or the mod is
inert for a default install. Process (Biki "Extensions" page, wording seen in search
results; the wiki itself blocked fetches today): BattlEye contact page, topic "Other
requests", subject "Arma extension whitelisting", a link to the DLLs in the message. It is
per file hash, so **every rebuild of a DLL is a new submission**. Turnaround is reported as
days to weeks.

There is no rush, so the DLLs are not submitted early: they get finished, flown and left
alone until nothing else wants to change, then submitted once. Everything tunable lives in
SQF and CBA settings, never in the DLLs. v1.0 goes public only after the whitelist is
confirmed by a BattlEye-on flight. Until then the mod's own first-run check says "launch
without BattlEye" when the extension fails to load.

## The DLLs

The extension API stays as it is (`version`, `status`, `zero`, `pose`) plus two commands so
the mod can set itself up from inside the game:

| Command | Does |
|---|---|
| `install` | Writes `HKCU\Software\Freetrack\FreetrackClient\Path` = the folder hhl_x64.dll was loaded from (found with `GetModuleFileNameW`), and remembers that path in `HKCU\Software\HelicopterHorizonLock\RegisteredPath`. Refuses if `Path` already exists and is not the remembered one (someone else's tracker, e.g. opentrack): returns `foreign:<path>`. |
| `uninstall` | Deletes `Path` only if it equals the remembered one. |

That is the only functional change: six advapi32 imports and one kernel32 import. Plus the
rename to `hhl` and the version string "hhl 1.0.0"; `FreeTrackClient64.dll` keeps its name
(the engine looks for it by name) and only its provider string changes.

The registry value points at the mod folder, wherever Steam put it. If Steam moves the
library the path changes; `status` then reports `notloaded`, the remembered path no longer
matches the folder, and `install` fixes it (it is ours, so overwriting is allowed).

64-bit only: the 32-bit executable is not what the Launcher starts on any 64-bit Windows,
and a 32-bit build doubles the BattlEye work. Documented as a requirement.

## v1.0 feature list

### Keeps

1. **Levelling** in first person while the player is the pilot of a helicopter (copilot
   dropped 2026-09-18 after the first addon flight: not wanted).
   Pitch and roll cancelled up to the limits, yaw untouched. Levelling pauses while a look
   action is held, so looking around is vanilla and resumes on release. The 1-frame
   prediction lead stays as a fixed internal (no setting): 6 ms at 168 fps, but 25 ms at
   40 fps.
2. **Zero pose whenever not levelling**: switched off, third person, not in a helicopter
   seat, next mission start. The head recentres and vanilla is exactly vanilla.
3. **Toggle** between levelled and vanilla, two ways: a CBA keybind (keyboard, in
   Configure Addons) and a custom-action slot (Use Action 1..20) polled per frame, because
   CBA keybinds cannot see joystick buttons. Toggle state persists for the mission.
4. **Auto-on** when taking a helicopter seat (setting, default on).
5. **CBA settings**, client-side, category "Helicopter Horizon Lock":

   | Setting | Type | Default |
   |---|---|---|
   | Enabled | checkbox | on |
   | Start levelled when entering a helicopter | checkbox | on |
   | Pitch limit (deg) | slider 0..90 | 90 (never unlocks) |
   | Roll limit (deg) | slider 0..45 | 45 (the engine caps tracker roll at 45) |
   | View pitch offset (deg) | slider -20..+20 | 0 (keeps the aircraft's default head angle) |
   | Joystick toggle slot | list: none, Use Action 1..20 | none |
   | Register the head tracker automatically | checkbox | on |

   The keyboard toggle defaults to Ctrl+Shift+H (the harness key, no flight collision).
6. **First-run and self-check**, run once per session with rate-limited hints:
   - extension returns nothing: "BattlEye or a missing DLL blocked Helicopter Horizon
     Lock; launch without BattlEye" (until whitelisted, then this text goes);
   - `status` = `notloaded` and the registry value is absent: `install`, then "restart
     Arma once";
   - `status` = `foreign`: name the other tracker's path, do nothing;
   - polls not rising while in a helicopter: "enable FreeTrack under Options >
     Controls > Controllers".
7. **Packaging**: `@HelicopterHorizonLock` = `addons/hhl_main.pbo` + `.bisign`,
   `keys/hhl.bikey`, `hhl_x64.dll`, `FreeTrackClient64.dll`, `mod.cpp`, `meta.cpp`,
   `LICENSE`, `README.md`. Built and signed by HEMTT, `requiredAddons[] = {"cba_main"}`,
   `hasInterface` guard, no server-side part. CBA_A3 listed as a required item on the
   Workshop page.
8. **Documentation on the page and in the README**: what the two DLLs do, the registry
   value and how to remove it, the head-tracking checkbox, the BattlEye status, "not for
   use alongside a real head or eye tracker (TrackIR, Tobii, opentrack): the engine has
   one head-tracking slot", multiplayer note (client-side; a server that verifies
   signatures must accept `hhl.bikey`).

### Cuts (never ship)

| Cut | Why |
|---|---|
| Takeover methods M0..M4, render-to-texture, eye offsets, hide-pilot, FOV keys, HUD toggle | Dead routes; the head-tracker route replaced all of them |
| Strength (half cancellation), washout, soft knee, smoothing | Flown and rejected: two references moving at different rates cause nausea |
| Hiding the nose marker (the V) | Masking the showHUD "direction" element did not hide it in flight (pilot report). The marker stays; a proper replacement is a later item |
| Limit cycling and stepping keys | Replaced by the two sliders |
| Head modes, loop mode (Draw3D), burst log, 1 Hz RPT log, on-screen readout | Dev instrumentation; stays in the harness under `tests/` |
| Yaw | Never sent; the engine yaw stays the aircraft's |
| Planes, gunner and passenger seats | Different problem (banked turns are the point of a plane); not asked for |
| 32-bit DLLs | See above |
| Trim key (Ctrl+Shift+T) | Becomes the "View pitch offset" slider |
| Coexistence with real head or eye trackers | Not wanted. Quick-look left and right covers looking around; the pilot's Tobii stays off |

### Later (tracked, not in v1.0)

- Directional levelling: rotate the pitch and roll correction into the current look
  direction so looking around while banked stays level (the pilot: "ultimately ideal").
  Needs a measurement of how the engine composes the tracker pose with look input; the
  *Cont look actions read the tracker pose back and may be the probe.
- A rolled aircraft symbol to replace the flat nose marker (needs a way to hide the
  engine's one first).
- Per-aircraft memory of limits and pitch offset.
- Soft knee, only if a user asks for it with a reason.

## Repository clean-up

| Item | Action |
|---|---|
| `bin/*.exp`, `bin/*.lib`, `native/out/` | Delete, add to `.gitignore` (build artefacts) |
| The two DLLs | Committed at the repo root, which is the mod root: HEMTT copies included files with their path kept, and `callExtension` looks only in the mod root. 2.5 KB and 6 KB; the shipped hashes must be reproducible from the repo |
| `tools/joystick/` | Move out of this repo; it is about the pilot's stick, not the mod |
| `research/` | Keep as `docs/research/` (history; the README stops pointing readers there first) |
| `tests/feasibility/` | Keep (harness, KEYS.md, RESULTS.md); mark as not part of the mod |
| `README.md` | Rewrite for players: what it does, install, first run, settings, limits, removal, troubleshooting; a short "Development" section at the end. Doubles as the Workshop description |
| `PLAN.md` | This file; becomes `ROADMAP.md` or is deleted at 1.0 |
| New files | `LICENSE` (MIT), `CHANGELOG.md`, `.hemtt/project.toml`, `mod.cpp`, `meta.cpp`, `addons/main/...` per `docs/research/03-tooling-and-structure.md`, `workshop/` (description, preview image) |
| Rename | `hzc` to `hhl` in sources, DLL name, harness console lines and docs; repo folder can stay `arma3-horizoncam` or become `helicopter-horizon-lock` |
| Arma root | Delete the stray `hzc_x64.dll` from `B:\SteamLibrary\steamapps\common\Arma 3` once the addon ships its own |
| Registry on this PC | Delete the current value (points at the repo's `bin/`) before the first addon run so `install` is exercised |
| Nothing committed yet | First commit after the clean-up, so history starts clean |

## Sequence

No critical path. Each step is finished before the next; the DLLs are submitted once,
at the end, when nothing else wants to change.

1. Clean the repo, rename to `hhl`, first commit.
2. `winget install hemtt`, subscribe CBA_A3 (450814997), scaffold the addon, port the
   harness maths (`HZC_fnc_update` M5 branch) into `fnc_onFrame`, settings, keybind,
   custom-action poll, self-check.
3. DLLs: `install`/`uninstall`, rename, rebuild. Flown with the addon, BattlEye off.
4. Flight checks that gate the release:
   - Alt+mouse freelook composes on top of the pose; behaviour on Alt release (open since run 4).
   - Toggle from keyboard and from a joystick button; state after respawn,
     mission restart, third person and back.
   - Hummingbird and Huron: default head angle, pitch offset slider.
   - Per-frame cost of `callExtension` (expected microseconds).
   - Fresh profile: registry absent, head tracking off; the first-run hints in order.
5. README for players, Workshop description, preview image, CHANGELOG.
6. Workshop item, hidden: `hemtt publish`, subscribe on this PC, run from the Launcher
   with the Workshop copy (not the dev folder), registry pointing at the Workshop folder.
7. DLL freeze: add `/Brepro` to the linker flags in build.cmd first (two builds of the same
   source currently differ in the PE timestamp, so the hashes are not reproducible), then
   version 1.0.0, SHA-256 of both, tag `dll-1.0.0`, GitHub release with the
   DLLs, submit both to BattlEye.
8. Whitelist confirmed: BattlEye-on flight. Then public, GitHub release `v1.0.0` with the
   zip and the DLL hashes.

## Decisions (2026-09-18)

1. Steam Workshop + GitHub.
2. Name "Helicopter Horizon Lock", prefix `hhl`.
3. Licence MIT.
4. 64-bit only.
5. Registry: register automatically when no other tracker is set, never overwrite a
   foreign value.
6. Defaults: keyboard toggle Ctrl+Shift+H, joystick slot none.
7. Commit the built DLLs.
8. Move `tools/joystick/` out of the repo.
9. No rush: finish and fly everything, submit the DLLs to BattlEye once at the end.
10. Nose-marker hiding cut for v1 (did not work in flight).
11. No coexistence with real head or eye trackers, now or later.
