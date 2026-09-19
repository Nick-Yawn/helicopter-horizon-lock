# Native side: the mod is its own head tracker

Arma 3 has a built-in FreeTrack head-tracking client. Strings in `arma3_x64.exe`
(2.22) show the whole interface:

- registry key `HKCU\Software\Freetrack\FreetrackClient`, value `Path` (a folder)
- it loads `FreeTrackClient64.dll` from that folder at start-up
- it imports `FTGetData`, `FTGetDllVersion`, `FTReportName`, `FTProvider`
- the same code path also serves TrackIR (`NPClient64.dll`) and Tobii EyeX; all three are
  `MovementTracker` subclasses, so FreeTrack data gets the full head treatment: yaw,
  pitch and roll in the cockpit, composed with mouse freelook by the engine.

So the mod does not need opentrack or any other program. It ships two tiny DLLs, built
into the repo root, which is the mod root:

| File | Loaded by | Job |
|------|-----------|-----|
| `FreeTrackClient64.dll` | the engine, at start-up, from the registry folder | answers `FTGetData` with whatever pose was last pushed in |
| `hhl_x64.dll` | `callExtension "hhl"`, from the Arma root or a mod folder | receives the pose from SQF each frame and pushes it into the tracker DLL (found in-process with `GetModuleHandle`); registers the tracker |

No shared memory, no sockets, no threads. `FTGetData` bumps `DataID` on every poll so the
engine never sees the data as stale.

## Extension API

```sqf
"hhl" callExtension "version"                     // "hhl 1.0.0"
"hhl" callExtension "status"                      // "tracker=ok polls=1234" | "tracker=notloaded" | "tracker=foreign"
"hhl" callExtension "zero"                        // recentre the head
"hhl" callExtension ["pose", [yaw, pitch, roll]]  // integer millidegrees; FreeTrack signs: yaw + = left, pitch + = up, roll + = left
"hhl" callExtension "install"                     // "ok" | "foreign:<path>" | "error"
"hhl" callExtension "uninstall"                   // "ok" | "foreign:<path>"
```

`polls` must keep rising while Arma runs; that is the proof the engine loaded our tracker
DLL. `tracker=notloaded` means the registry value is missing or Arma was not restarted
after it was set. `tracker=foreign` means another FreeTrackClient64.dll (opentrack's, for
instance) is loaded instead of ours.

`install` writes `HKCU\Software\Freetrack\FreetrackClient\Path` = the folder hhl_x64.dll
was loaded from (`GetModuleFileNameW`) and remembers that folder in
`HKCU\Software\HelicopterHorizonLock\RegisteredPath`. If `Path` already exists and is not
the remembered one it belongs to someone else's tracker: nothing is written and the reply
is `foreign:<that path>`. `uninstall` deletes both values while `Path` still equals the
remembered one; if `Path` is already gone it does nothing and answers `ok`. The engine
reads `Path` at start-up, so both need a restart to take effect.

## Build

`native/build.cmd`. Uses only the MSVC 14.29 toolset already on this PC; no Windows SDK
is installed, so the sources include no headers, link no C runtime (`/NODEFAULTLIB`,
entry point `DllMain`), and the kernel32 and advapi32 imports come from import libraries
that `lib.exe` generates from `kernel32.def` and `advapi32.def`. Intermediates go to
`native/out/`, the DLLs to the repo root. With the HEMTT dev layout Arma runs copies of
the DLLs under `.hemttout\dev`, so the build works with the game open; the copies refresh
on the next `hemtt dev` or `hemtt launch`, which needs the game closed.

Run it from a Command Prompt or PowerShell by full path (from Git Bash the path gets
mangled and nothing builds):

    cmd /c C:\Users\Nicho\projects\arma3-horizoncam\native\build.cmd

The link step uses `/Brepro`, so a rebuild from the same source with the same toolset
(MSVC 14.29) gives byte-identical DLLs: the PE timestamp is a hash of the content, not the
link time. SHA-256 of the DLLs built from this source:

    hhl_x64.dll            e8e283721f60b20ee811b86731f40230eaf40314cd7e4725511008faca32c60d
    FreeTrackClient64.dll  5327ece84018b864f5c940d3e882371ba5eb618a4d06d377b9a739383e2b906c

## Registering the tracker by hand

The addon does this itself on first run (setting "Register the head tracker
automatically"). To do it without the addon:

```
reg add "HKCU\Software\Freetrack\FreetrackClient" /v Path /t REG_SZ /d "<folder holding FreeTrackClient64.dll>" /f
```

Restart Arma. Then `"hhl" callExtension "status"` in the debug console must say
`tracker=ok polls=N` with N rising. To undo: `"hhl" callExtension "uninstall"`, or
`reg delete "HKCU\Software\Freetrack\FreetrackClient" /f`.

## BattlEye blocks unknown DLLs

With BattlEye enabled (the launcher adds `-beservice`), the RPT shows

    Call extension 'hhl' could not be loaded: Insufficient system resources exist to complete the requested service.

That text is BattlEye refusing the load, not Windows running out of anything: BattlEye
hooks every DLL load in the game process and only lets through DLLs on its whitelist.
The same filter applies to the tracker DLL the engine loads at start-up. For development
and single player, launch without BattlEye (Launcher, Parameters, untick BattlEye, or run
`arma3_x64.exe` directly). For release on BattlEye-protected servers the two DLLs must
be submitted to BattlEye for whitelisting, as Intercept, ACE, TFAR and ACRE do.

## The tracker must be enabled in the profile

The engine loads the DLL regardless but only polls it when the head-tracking controller
is enabled: `class trackIRClass { enabled=1; }` in the `.Arma3Profile`, set in-game under
Options > Controls > Controllers, where the entry is labelled "FreeTrack" (TrackIR and
Tobii share that one entry). `ownSettings=1` means the engine applies no curves of its own.

## Measured on 2026-09-18 (run 4, Huron, Arma 3 2.22)

- Roll is applied in the pilot seat. Pitch and roll both move the right way with the
  FreeTrack signs above.
- The engine does not read the value as radians. Sending r radians produced
  `360 * r` degrees of head pitch and `180 * r` degrees of head roll (fits: 6.25 and
  3.18 engine degrees per degree sent, i.e. 2π and π). It treats the value as a
  normalised angle, the same way it normalises TrackIR's ±16383 units. The harness
  divides by `HZC_gainPitch` / `HZC_gainRoll` before sending; the addon does the same.
- The vehicle's default head angle stays in: the rendered view sits about 6 degrees
  nose-down on the Huron with zero sent.

## Settled since

- Latency is one frame: the pose computed in frame N is polled at the start of frame N+1.
  The addon predicts one frame ahead to cover it.
- Mouse freelook composes on top of the pose and snaps back on Alt release, which is
  vanilla.
- The engine clamps tracker roll at 45 degrees in the pilot seat, which is why the roll
  limit setting ends at 45.
- Yaw gain is still unmeasured because yaw is never sent.
