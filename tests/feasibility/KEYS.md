# Horizon camera harness: keys and console commands

All keys are **Ctrl + Shift + key**. They only exist while the harness is loaded
(`[] execVM "horizoncam_test.sqf";` in the debug console). Every press prints what it
did in system chat and in the RPT.

## Flying with it

| Key | Does | Values |
|-----|------|--------|
| **H** | Horizon camera on / off. Off also recentres the head | |
| **Use Action 1** (no modifier; bind any key or joystick button under Configure, Controls, Custom) | Same toggle as H, for a flight-stick button | |
| **K** | Cycle the pitch and roll limit | 90 → 25 → 15 → 7 → 0 (90 = no knee, horizon fully locked; 0 = vanilla view) |
| **,** / **.** | Limit down / up by one degree, pitch and roll together | 0 to 90 |
| **W** | Washout: level against a slow average of your own attitude instead of the true horizon, so only fast wobble is cancelled | 0 (off) → 1 → 2 → 4 s |
| **N** | Strength: fraction of the tilt cancelled inside the limit | 1 → 0.75 → 0.5 → 0.25 |
| **G** | Soft knee: degrees of gradual transition either side of the limit | 0 (hard) → 2 → 4 |
| **P** | Prediction lead, to cover the tracker's one-frame lag | 1 → 0 → 2 frames |
| **T** | Pitch trim: centre the view on the fuselage line instead of the vehicle's default slightly-down view. Press again to clear. Only while the camera is on, with freelook centred | |

## Diagnostics

| Key | Does |
|-----|------|
| **B** | Burst log: one `[HZC-B]` line per frame for 3 seconds (lag measurement). Press during a hover with some inputs |
| **L** | On-screen readout on / off |
| **Backspace** | Shut the harness down completely (camera released, all keys removed) |

## Only relevant to the old camera methods (M0 to M4), ignore for M5

| Key | Does |
|-----|------|
| **M** | Next takeover method, only while the camera is off. M5 (head tracker) is the one in use |
| **J** | Head mode 0 to 3 |
| **Y** | Per-frame hook: EachFrame / Draw3D |
| **U** | HUD flag for scripted cameras |
| **[** / **]** | Scripted camera field of view |

## Debug console

Load or reload the harness (reloading picks up an updated file and replaces the old handlers):

```sqf
[] execVM "horizoncam_test.sqf";
```

Is the engine polling our tracker DLL? Put this in a WATCH field; `polls` must keep rising:

```sqf
"hhl" callExtension "status"
```

Separate pitch and roll limits (the keys always set both):

```sqf
HZC_limitPitch = 12; HZC_limitRoll = 7;
```

Other settings you can change live: `HZC_strength`, `HZC_knee`, `HZC_leadFrames`,
`HZC_washout`, `HZC_pitchTrim`, `HZC_smoothTau` (output smoothing, adds lag, 0 = off),
`HZC_hideDirMarker` (true hides the engine's V-shaped vehicle-direction marker while
active; it is the freelook nose marker, not an attitude indicator), `HZC_toggleAction`
(the custom action name for the toggle, default `"User1"`, `""` to disable),
`HZC_gainPitch` / `HZC_gainRoll` (engine degrees per degree sent, 2π and π),
`HZC_signPitch` / `HZC_signRoll` (1 and -1, both confirmed correct).

If the view is ever left broken (black screen, stuck camera):

```sqf
call HZC_fnc_repairView;
```

Remove everything:

```sqf
call HZC_fnc_shutdown;
```

## One-time setup reminders

- Launch **without BattlEye** (it blocks the DLLs).
- `hhl_x64.dll` in the Arma 3 root; `FreeTrackClient64.dll` in the project `bin` folder,
  which the registry value `HKCU\Software\Freetrack\FreetrackClient\Path` names.
- Head tracking enabled in Configure, Controls, Controllers (the TrackIR entry).
- The harness file must be copied into each mission's folder.
