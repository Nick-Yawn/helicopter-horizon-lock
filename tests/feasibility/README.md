# Feasibility test: horizon-locked first-person helicopter camera

This is the go/no-go for the whole idea. It uses a throwaway script,
`horizoncam_test.sqf`, run from the debug console. No addon, no CBA, no HEMTT.
Budget an evening.

What it answers, in the numbering of `docs/research/README.md`:

| Test | Question | Where you read the answer |
|------|----------|---------------------------|
| T1 | Do flight controls survive a scripted camera? | Fly. Also the `heli` input line of the readout |
| T2 | Does the engine head direction still follow freelook and TrackIR? | `head rel yaw / pitch` line while freelooking |
| T3 | Which input actions still read under the camera? | The `look` input line |
| T4 | Does the 2D HUD and the AH-99 helmet symbology draw? | Look. Toggle with Ctrl+Shift+U |
| T4b | Is the cockpit rendered from the pilot interior model, with live instruments? | Look at gauges and MFD screens |
| T5 | EachFrame vs Draw3D jitter | Ctrl+Shift+Y at speed with fast rolls |
| T8 | Do NVG and thermal toggles reach the camera? | Press N; `visionMode` in the readout |
| T11 | Where is the engine eye point relative to `eyePos`? | `eyePos-anchor` distance |
| T14 | Does `getObjectFOV` track RMB and numpad zoom? | `getObjectFOV` line while zooming |
| T0 | Is the attitude maths right? | `basis err` must stay near 0.00000 |

## Setup, once

1. **Launcher parameters.** In the Arma 3 Launcher, Parameters tab, tick
   *Show script errors* (adds `-showScriptErrors`). Optional but useful:
   *Window* and *No pause* so Alt-Tab does not freeze the game.
2. **Eden mission.** Start the game, Editor, pick VR or Stratis.
   - Place an *MH-9 Hummingbird* (no HUD symbology) and an *AH-99 Blackfoot*
     (helmet-mounted HUD symbology). Vehicles come with crew.
   - Expand the MH-9 crew, select its pilot, open Attributes, and set Control to
     *Player*. You will swap to the AH-99 in-game later.
   - Save the mission (Ctrl+S) as `hzc_test`. Arma writes it to the `missions`
     folder of the profile you are playing on. On this PC only the `Nick_Yawn`
     profile has one, so expect
     `Documents\Arma 3 - Other Profiles\Nick_Yawn\missions\hzc_test.<Map>`.
     If you play on another profile, look under `Documents\Arma 3\missions` or
     `Documents\Arma 3 - Other Profiles\<profile>\missions`.
3. **Copy the script** `horizoncam_test.sqf` into that mission folder, next to
   `mission.sqm`.
4. Play the mission (Play in Singleplayer).

## Running it

1. In the pilot seat, in first person (Num Enter toggles), press Esc, and in the
   debug console EXECUTE field run

   ```sqf
   [] execVM "horizoncam_test.sqf";
   ```

   then click LOCAL EXEC and close the menu. A hint lists the keys.
2. Press **Ctrl+Shift+H**. The readout appears top right. The camera should look
   identical to before at first, since the airframe is level.
3. Fly. Bank and pitch inside 30 degrees: the horizon should stay level while the
   cockpit tilts around you. Go past 30 degrees: the camera should start to follow
   at a fixed 30 degree offset. **Ctrl+Shift+K** cycles the limit; 0 means the
   camera follows the airframe exactly, which should look like vanilla first person
   and is a good sanity check.
4. Work through the tests below. Press **Ctrl+Shift+H** again to hand the view back
   at any time, and **Ctrl+Shift+Backspace** to remove the harness entirely.

If the camera ever gets stuck, run `call HZC_fnc_shutdown;` in the debug console.

## Test procedure and what to note

Write your observations into `RESULTS.md` next to this file, or just tell me. The
RPT log captures the numbers, so a rough note per test is enough.

**T1, flight control (blocking).** With the camera active, fly a circuit: collective
up and down, cyclic on all axes, pedals, autohover, gear if fitted, fire the gun on
the AH-99, lock a target. Try every input device you use, including mouse cyclic if
you fly that way. Note anything that stops working. If something is dead, note
whether it comes back when you press Ctrl+Shift+H to hand the view back.

**T2, head pose.** With head mode 0 (the default, display only), hold Alt and move
the mouse, or move your head if you have TrackIR. Watch the `head rel yaw / pitch`
numbers and the `gCVD` and `eyeDir` vectors. Three possible outcomes:
- They move with your head: the engine head is still readable. Press Ctrl+Shift+J
  to head mode 1 and confirm the camera now turns with freelook while the horizon
  stays level. Best case.
- They do not move at all: the head is frozen under a scripted camera. The mod will
  need to re-implement the head from input actions (T3).
- They track the scripted camera instead of your head: `pCTW-cam` will be near 0
  and the vectors will match the camera direction. Same conclusion as frozen.
Also try head mode 2 to compare `eyeDirection`.

**T3, input actions.** Still under the camera, hold Alt, move the mouse, press
numpad look keys, hold right mouse, press Num plus and minus, press N. The `look`
line shows each action's current value. Note which ones respond and which stay at
0. Then do the same with the camera off for comparison.

**T4, HUD.** On the AH-99, with the camera active, is the helmet symbology (horizon
bar, heading tape, gun cross) drawn? Is it aligned when you roll past the limit and
the camera and airframe diverge? Is the 2D vehicle info panel and radar visible?
Press Ctrl+Shift+U to toggle the HUD flag and see what changes.

**T4b, cockpit model.** Compare the cockpit with the camera on and off. Are the
instruments and MFD screens live or blank? Does the interior look lower detail or
show glass artefacts? This tells us whether a scripted camera gets the pilot
interior model.

**T5, jitter.** At 200 km/h with fast rolls, does the cockpit swim relative to the
horizon? Press Ctrl+Shift+Y to switch to Draw3D and compare.

**T8, vision modes.** Press N at night or in a dark hangar. The readout's
`visionMode` should change and the camera should follow. Note if the camera stays
in daylight while the readout says 1.

**T11, eye anchor.** `eyePos-anchor` is the distance in metres between the engine's
sampled camera point and `eyePos`. Note the value. Shift your head with Ctrl plus
numpad and see if either moves.

**T14, zoom.** Hold right mouse and press Num plus and minus. Does `getObjectFOV`
change? Does the actual view zoom? Ctrl+Shift+[ and ] change the scripted camera's
own field of view for comparison.

**Lifecycle.** With the camera active, eject, and separately switch seats and get
out on the ground. The harness should release itself and log why. Note any case
where the view is left broken.

**T12, new commands.** In the debug console, run

```sqf
supportInfo "n:enableFreeLook"
```

and

```sqf
supportInfo "n:getAimDirectionAndUp"
```

and paste what the WATCH field shows. Their documentation was unreachable.

## Afterwards

The RPT file is the newest `Arma3_x64_*.rpt` in `%LOCALAPPDATA%\Arma 3`. Every
harness line starts with `[HZC]`. I can read it directly from this machine, so just
say when you are done and note anything you saw that a number cannot capture.

## Run 2: takeover methods (after run 1 showed the plain cutscene camera cuts vehicle input)

Run 1 first looked as if a cutscene camera stops the engine delivering input to the
helicopter. That reading was withdrawn: the aircraft was losing its tail rotor because
of its editor placement, which explains the runaway yaw by itself. So the plain method
(M0) is unproven rather than dead, and it is the cleanest option if it works. Test it
first, properly placed and in a stable hover, then the fallbacks. Two precautions
either way:

- **Centre and release every control before pressing Ctrl+Shift+H**, in every method.
  If a method turns out to freeze input, you want it frozen at neutral.
- Do these tests in a **hover a few hundred metres up**, not on the ground, and hand
  the view back the moment something feels wrong.

The harness has five takeover methods. **Ctrl+Shift+M** cycles them while the
camera is off, and the readout's first line names the active one. Default is M3;
press Ctrl+Shift+M three times to reach M0 (M3, M4, M0), or run `HZC_method = 0;`
in the debug console while the camera is off.

| Method | What it does | What to test |
|--------|--------------|--------------|
| M3 proxy | A hidden object is placed at the eye point every frame and the engine's own view command is switched onto it. Not a cutscene camera | Fly. If control survives, this is the winner. Note whether the view sits at the right spot and whether the cockpit is visible |
| M4 render-to-texture | The engine pilot view stays primary; our camera is drawn over it from a texture | Control must survive here. Judge whether the picture quality and view distance are tolerable. Set PiP quality to Ultra in video options first |
| M1 manual off | Cutscene camera with its keyboard/mouse control explicitly disabled | Quick check only: does collective respond? |
| M2 external effect | Cutscene camera in the other effect mode | Quick check only |
| M0 plain cutscene camera | Run 1's method, verdict withdrawn after the tail-rotor finding | **Test first.** Stable hover, controls centred, then fly. If everything works, M3 and M4 are unnecessary |

For each method that keeps control, also do the freelook check from T2: hold Alt
and move the mouse, and watch whether `head rel yaw / pitch` follows. Run 1 already
showed the engine keeps computing the pilot's head under a cutscene camera, so this
should work; it just was not exercised.

If the view is left broken after a method, run `call HZC_fnc_shutdown;` in the
debug console.

## Run 4: M5, the head-tracker route (no camera at all)

Runs 2 and 3 settled it: M0 to M3 lose control and M4's picture is unusable. M5 leaves
the engine's pilot view alone and counter-rotates the pilot's head through the engine's
own FreeTrack head-tracking input. Two DLLs from `native/` do the plumbing; nothing else
runs. Details in `native/README.md`.

**One-time setup** (a restart of Arma is needed after step 2):

1. `hhl_x64.dll` (repo root) must sit in the Arma 3 root folder (done from this PC).
2. Tell the engine where the tracker DLL is (user registry, no admin):

   ```
   reg add "HKCU\Software\Freetrack\FreetrackClient" /v Path /t REG_SZ /d "C:\Users\Nicho\projects\arma3-horizoncam" /f
   ```

3. Start Arma, load the mission, run the harness. Before anything else, in the console:

   ```sqf
   "hhl" callExtension "status"
   ```

   Expected: `tracker=ok polls=N`. Run it twice; N must rise. `tracker=notloaded` means
   the registry value is missing or Arma was not restarted.

**Tests**, in a hover a few hundred metres up, first person, M5 (the default):

| # | Do | Read |
|---|----|------|
| R4-1 | Ctrl+Shift+H, then Ctrl+Shift+K until the limit is 5 | Readout line `M5 sent` shows non-zero pitch/roll as you wobble; `ext` says `["ok",0,0]` |
| R4-2 | Small pitch and roll inside 5 degrees | Horizon stays level; `rendered cam pitch/roll` follows `cam pitch/roll`, not `heli` |
| R4-3 | Wrong direction on an axis? | Console: `HZC_signPitch = -1;` or `HZC_signRoll = 1;` and compare again |
| R4-4 | Roll only, well inside the limit | Does the rendered cam roll change at all? If not, the engine ignores tracker roll in the pilot seat |
| R4-5 | Hold Alt and look around, release Alt | Freelook composes on top; note what the release does to the levelled view |
| R4-6 | Fast rolls at speed | Lag or swim between cockpit and horizon |
| R4-7 | Ctrl+Shift+H off, eject, seat switch | Head recentres (zeros sent); nothing left tilted |

The RPT line now carries `camW=[yaw pitch roll]` (the camera actually rendered),
`sent=[pitch roll]`, `signs`, `ext` and `trk` (tracker status with the poll count).
