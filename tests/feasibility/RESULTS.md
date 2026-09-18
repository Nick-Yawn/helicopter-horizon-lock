# Feasibility results

Log source: `%LOCALAPPDATA%\Arma 3\Arma3_x64_2026-09-18_09-35-18.rpt`, lines prefixed `[HZC]`.
Aircraft: MH-9 Hummingbird (B_Heli_Light_01_F), Altis, Nick_Yawn profile, Arma 3 2.22.

## Run 1 (2026-09-18, method: cameraEffect on a "camera" object)

| Item | Result | Evidence |
|------|--------|----------|
| Harness loads and activates | Yes | ACTIVATED lines; allCameras lists our camera as primary with effect "Internal" |
| T0 attitude maths | Pass | `basis err` = 0.00000 on every sample |
| T1 flight control | **FAIL as reported by pilot** | Last activation shows yaw rate ~165 deg/s sustained, consistent with a pedal input the vehicle never saw released |
| T2 head pose (no freelook applied yet) | Promising | `getCameraViewDirection player` kept reporting the engine pilot view: airframe pitch minus the MH-9's 3 degree ViewPilot initAngleX, not our level camera. So the engine head is still computed under a scripted camera. Freelook itself was not exercised this run |
| positionCameraToWorld | Follows the scripted camera | `pCTW-cam` 0.000 to 0.05 m |
| T11 eye anchor | Sampled fine | anchor (model) [-0.35, 1.21, 0.23]; `eyePos` differs by 0.003 m at rest and up to 0.7 m while manoeuvring (simulation-scope lag, expected) |
| FOV | ViewPilot initFov 0.90 picked up; `getObjectFOV` reports 0.900 for player and vehicle | no zoom exercised |
| T8 vision | Not exercised (daylight) | vm=0 throughout |

Open: which inputs exactly die (keyboard, mouse cyclic, joystick), whether the
pedal spin was a stuck key at toggle time, and whether the alternative takeover
methods behave differently. See run 2.

Pilot's note after run 1: yaw control was also lost at some point, timing unclear.
Consistent with the log: the last activation shows a sustained ~165 deg/s yaw with
all pedal inputs reading 0, i.e. the vehicle kept the last pedal command it received
before the takeover and never saw the release.

Conclusion for M0 (cameraEffect): input is read but not delivered to the vehicle.
Not viable for a pilot. Run 2 tests M1 to M4.

**Correction (pilot, same day):** the helicopter's tail rotor was breaking off because
of where it was placed in the editor. A lost tail rotor fully explains the runaway yaw
on its own, and a damaged or engine-off aircraft would also explain "collective held,
no attitude change". The M0 verdict above is therefore withdrawn to *unproven*. Run 2
retests M0 first with the aircraft placed properly, then M3 and M4.

## Run 2 (2026-09-18, aircraft placed properly, methods M0 to M4)

| Method | Flight control | Evidence and notes |
|--------|----------------|--------------------|
| M0 cutscene camera, Internal | **Lost** | Inputs read (pedal up to 0.92, collective 1.0) while the airframe ran through stale commands; pilot confirms |
| M1 as M0 + camCommand manual off | **Lost** | Same behaviour; the camera was not the one eating input |
| M2 cutscene camera, External | **Lost** | Same behaviour |
| M3 engine view switched onto hidden proxy object | **Lost, worse** | `cameraOn` became the proxy; helicopter pitched up on its own (23 to 50 deg in 10 s) and lost its tail rotor. Engine reroutes input when the view leaves the vehicle |
| M4 engine pilot view primary, our camera via render-to-texture | **Works** | `cameraOn` stays the helicopter; airframe answered pedal within the same second; 57 s of flying |

Deadzone maths verified in flight under M4: airframe pitch -46.7 gave camera pitch
-16.7 (limit 30), roll -34.3 gave camera roll -4.3. `basis err` 0 throughout.

M4 problems seen:
1. Picture very low resolution. PiP video setting was not raised; harness now requests
   a 2048 texture (`HZC_rttSize`). Retest with PiP on Ultra.
2. Camera at the exact engine eye point sees the inside of the pilot's head; the engine
   hides the head only in its native view. Forward offset tried and rejected by the
   pilot. Next: `HZC_hidePilot` hides the pilot model while M4 is active.
3. Not yet assessed under M4: HUD visibility beneath the picture, freelook (head mode
   1), zoom and NVG mirroring, view distance and post-processing of the texture.

Warning fixed: a Control stored in a mission-namespace global ("hzc_pic does not
support serialization"); it now lives in uiNamespace.

## Direction after run 2

Only M4 keeps control, and it pays for it in picture quality and complexity. The
pilot suggested a freelook-based approach: drive the engine's own head instead of
replacing the camera. The engine head has yaw, pitch and roll freedom in helicopters
and everything stays native. No scripting command sets the head pose, so the realistic
route is a virtual head-tracking device: the mod computes the counter-rotation, a small
extension passes it to a virtual tracker (opentrack, TrackIR protocol), Arma applies
it as head tracking. Cheap in-engine experiment first: head mode 3 makes the player
`doWatch` a levelled point every frame to see whether the engine head turns at all.
Also check `supportInfo "n:enableFreeLook"` in the debug console.

## Run 3 (2026-09-18, M4 with PiP raised, pilot hidden)

| Item | Result | Evidence |
|------|--------|----------|
| Freelook on top of the levelled camera (head mode 1) | **Works** | 187 s in head mode 1, head yaw relative to airframe ranged -27 to +32 deg and pitch -40 to +10 deg, `lookAround` action seen; pilot confirms the picture turns with the head while the horizon stays level |
| Limit feel | 30 far too high; **15 already on the high side** | Pilot cycled 15, 45, 90, 0, 30, 15. Only the small attitude changes near hover should be cancelled; forward-flight attitude should come through |
| Head-watch experiment (doWatch a levelled point, head mode 3) | No head movement | 31 s under M4, head relative to airframe stayed within 2 deg. Not fully conclusive because the watch point was near straight ahead in a hover; the console one-liner (50 m north, 30 m up) was not reported |
| supportInfo check for the 2.22 commands | Not run | No log line |

Harness changes after run 3: default limit 10, cycle 10 / 5 / 15 / 20 / 30 / 0,
Ctrl+Shift+comma and period step the limit by one degree.

Design consequence: the deadzone is a hover aid, not a general stabiliser. Expect the
shipped defaults around 5 to 10 degrees, with a soft transition worth trying next.

## Run 4 (2026-09-18, Huron B_Heli_Transport_01, Stratis, hzc_test2): M5 head-tracker route

Setup findings before any flying:

- BattlEye (launcher default, `-beservice`) blocks the extension: RPT says
  `Call extension 'hzc' could not be loaded: Insufficient system resources exist to
  complete the requested service.` Launching without BattlEye fixed it.
- The engine loaded `FreeTrackClient64.dll` from the registry folder (`tracker=ok`) but
  polled it 0 times until the head-tracking controller was enabled in Controls,
  Controllers (`trackIRClass.enabled` was 0 in the profile). After that, polls rose at
  frame rate.

Flight evidence, from the RPT lines with polls > 0 (limit 5):

| sent pitch (deg) | head pitch change (deg) | sent roll (deg) | head roll change (deg) |
|---|---|---|---|
| +0.6 | +3.5 | +0.7 | -2.2 |
| +2.7 | +16.9 | -1.0 | +3.2 |
| +5.0 | +31.4 | -1.7 | +5.4 |
| | | +2.0 | -6.4 |

Least-squares fits: head pitch = 6.25 x sent, head roll = -3.18 x sent (the roll sign
is our own convention; the view moved the correct way on both axes). 6.25 ~ 2π and
3.18 ~ π: the engine reads the FreeTrack float as a normalised angle (1.0 = one turn for
pitch, one half-turn for roll), not radians. Pilot report: "getting movement of the
view, but overcompensating", which is exactly that gain.

Conclusions:

- Roll IS applied in the pilot seat. The full design (pitch and roll levelling) stands.
- Signs confirmed: FreeTrack pitch positive = up, roll positive = left.
- Fix: divide by the gains before sending (`HZC_gainPitch = 2 * pi`, `HZC_gainRoll = pi`).
- The rendered view keeps the vehicle's default head angle (-6 deg pitch on the Huron).
- Still to judge: lag in fast rolls, freelook composition, feel at 5 deg with the hard knee.

### Run 4, feel (later the same day, Huron, limits 7 then 25)

- Gains 2π / π confirmed in flight: pitch and roll now land within a few tenths of a
  degree of the request at the 1 Hz sample points; roll exactly. Frame rate ~168 fps, so
  the one-frame tracker lag is ~6 ms and the prediction lead makes no felt difference.
- **The knee is the motion-sickness trigger.** With the limit at 7, pitch crosses it on
  every acceleration and deceleration (roll rarely does in a hover), so the horizon keeps
  switching between locked and moving. Raising the pitch limit to 25 removed the nausea
  completely. Default is now 90 (no knee).
- Strength 0.5 (half cancellation) and washout (levelling against a slow average of the
  attitude) both made it worse: two references moving at different rates.
- The V-shaped symbol at the top of the screen is the engine's freelook nose marker
  (shown whenever the head is off the vehicle axis, which is now always). It is a flat
  sprite marking where the nose points and does not roll. The harness hides it via the
  showHUD "direction" element while active (`HZC_hideDirMarker`).
- Pilot wants a single button to switch between levelled and vanilla view: added a poll
  of custom action "Use Action 1" (bindable to a joystick button).
- Later the same day (pilot report): masking the showHUD "direction" element did not hide the
  V marker in flight. Marker hiding is cut for v1; the marker stays.

## Run 5 (2026-09-18, the addon, dev build at commit 12f434c, Nick_Yawn profile, BattlEye off)

Launched with `hemtt launch -Q -- -name=Nick_Yawn -showScriptErrors` (CBA_A3 from the Workshop).

- First run: self-check found the tracker not loaded, `install` wrote the registry value
  (`.hemttout\dev`, confirmed in the registry), hint "Restart Arma 3 once". Nothing else.
- Second run: **levelled on its own** in the pilot seat, first person, no hint. Auto-on and
  the profile head-tracking flag did the rest.
- **Freelook composes on top of the tracker pose** (open since run 4). Pilot: "feels weird
  but it works"; what is weird is not yet pinned down.
- Toggle between levelled and vanilla view works; pilot: "works really nicely".
- Still to fly from PLAN.md step 4: seat swap, respawn, mission restart, third person and
  back, Hummingbird vs Huron default head angle and the pitch offset slider, copilot seat.
- Third person: no effect, vanilla view (the pose is zeroed outside the cockpit view). Pass.
- Copilot seat: dropped by the pilot ("copilot doesnt matter"); the copilot turret check is
  to be removed from fnc_onFrame in the next code pass. Seat swap goes with it.
- Pitch and roll limit sliders work.
- Freelook: Alt+mouse composes and snaps back on release, as vanilla does. The pilots
  quick-look buttons (continuous look left/right, also snap-back) "behave strangely" while
  levelled: with the head yawed off the nose the pitch and roll corrections act on the
  wrong axes for the direction being looked at. Pilot idea: pause levelling while a look
  action is held. To be tried in the next code pass (a few lines), kept only if it flies well.
- Roll levelling stops at about 45 degrees of bank whatever the slider says (MH-9, limit 90): an engine cap on tracker head roll. Roll slider now stops at 45.
