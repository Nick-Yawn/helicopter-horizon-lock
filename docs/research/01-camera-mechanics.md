# Arma 3 camera mechanics for a horizon-levelled helicopter camera mod

Research date: 2026-09-18. Target: Arma 3 (Real Virtuality, v2.10–2.22 era). Priority: first person (internal pilot view); third person secondary.

How the sources were obtained: `community.bistudio.com` and `forums.bohemia.net` sit behind a Cloudflare bot check that returns 403 to direct fetches. The MediaWiki API (`/wikidata/api.php`) worked for the first ~50 requests (used for the Event Handler pages and the version categories) and was then rate-limited for the rest of the session. All remaining Biki command pages were read from Wayback Machine snapshots of the live pages (snapshot dates Jan–May 2025, noted per URL in section (e)). Vanilla config values come from a GitHub dump of the Arma 3 class tree. Everything quoted below is verbatim from those pages unless marked as inference.

Confidence scale used: **High** = stated verbatim on the Biki or in vanilla config; **Medium** = inferred from working mod code or forum posts by named authors; **Low** = plausible but unverified, needs the in-game test in section (d).

---

## (a) Executive summary — ranked approaches

**There is no config parameter and no scripting command that re-orients the engine's own `ViewPilot` (first-person) camera at runtime.** The Camera Control command group (68 commands, listed in full) and every command introduced in 2.10, 2.12, 2.14, 2.16, 2.18, 2.20 and 2.22 were checked by category listing; nothing sets an orientation offset on the player's view camera. `ViewPilot` angles/FOV/head-move limits are config-time clamps on player input, and `camSetBank` / `camSetDive` / `camPrepareBank` / `camPrepareDive` / `camPrepareDir` are all flagged **"This command is non-functional!"** on the Biki. A horizon-levelled first-person view therefore has to be a scripted camera.

Ranked approaches:

1. **Scripted `camCreate` camera driven per frame with `setPosASL` + `setVectorDirAndUp` (recommended, works for 1st and 3rd person).** Create `"camera" camCreate`, enter it with `cameraEffect ["Internal","BACK"]`, `camCommit 0`, then every frame: read the vehicle's rendered transform with the `*Visual` commands (`vectorDirVisual`, `vectorUpVisual`, `modelToWorldVisualWorld`/`modelToWorldVisual`), compute a levelled basis (yaw from the vehicle heading, up = world up, then clamp/drag beyond the configurable angle), and write it with `_cam setVectorDirAndUp [_dir,_up]` and `_cam setPosASL _eyeASL`. Set the FOV once with `camSetFov`/`camCommit 0` and re-apply when the player zooms. This exact pattern (per-frame `setPosASL` + `setVectorDirAndUp` on a `cameraEffect` camera, built from `modelToWorldVisualWorld` and `vectorModelToWorldVisual`, with the up vector from a double cross product) is what the Project Hatchet UH-60 mod ships for its full-screen FLIR camera, so it is known to run stably at helicopter speeds. Roll is set purely through the up vector; the Biki notes on `setVectorUp`/`setVectorDirAndUp` say the command "can be also used to rotate camera in all three axis (which also mean it is possible to set camera bank)". Confidence that this renders correctly: High. Confidence that the pilot keeps full flight control and freelook/TrackIR while it is active: **Low – this is the single most important in-game test** (see (d) T1–T3); the H-60 author documents that some vanilla user-action events stop firing under `cameraEffect` and had to fall back to raw `KeyDown` hooks.

2. **`switchCamera` onto a hidden proxy object (fallback if `cameraEffect` eats controls).** Killzone_Kid's documented trick: create `"Land_HandyCam_F"`, `hideObject true`, `attachTo` the vehicle, orient it with `setVectorUp`/`setVectorDirAndUp` (in parent model space), and `_cam switchCamera "Internal"`. This keeps the player in a "real" view mode rather than a cutscene camera. His example still needed `KeyDown`/`MouseButtonDown` handlers to re-issue fire/reload, so some inputs are intercepted here too. Confidence: Medium that it works as a camera; Low on control side effects.

3. **Third person only: config `extCameraParams[]` (Arma 3 1.70-era).** Documented on the CfgVehicles Config Reference: `factor == 0 -> camera follow horizon`, `factor == 1 -> camera follow vehicle heading`, values between interpolate, `{-1}` forces the old behaviour. Vanilla helicopters (MH-9, AH-99 dumps) ship `extCameraParams[] = {-1}` and `extCameraPosition[] = {0,2,-15}` / `{0,2,-20}`. This is a config-time, third-person-only knob (no runtime command), so it cannot implement the "drag beyond N degrees" rule, but a config patch is the cheapest way to get a horizon-following external camera. Confidence: High that the parameter exists with those semantics; Medium on what it does to roll specifically (needs T13).

4. **Not viable:** `camSetBank`/`camSetDive` (non-functional), camera-shake `bankCoef` (oscillation only), `setHorizonParallaxCoef` (shifts the rendered horizon line, not the camera), `enableFreeLook` (new in 2.22; page not retrievable this session — verify with `supportInfo` in game), `HeadAimDown`/`initAngleX` (static config pitch only).

---

## (b) Findings per question

### Q1. Built-in cameras (config and runtime)

#### ViewPilot / ViewCargo / ViewGunner / ViewOptics parameters

Biki CfgVehicles Config Reference (verbatim):

```
...AngleX/Y
Float Degrees
initAngleX = 0;
minAngleX = -30;
maxAngleX = 30;
initAngleY = 0;
minAngleY = -100;
maxAngleY = 100;
initFov = 0.700000;
minFov = 0.420000;
maxFov = 0.850000;
used by car.ViewPilot class
```
and under `minFov/maxFov`: "also used by ViewPilot Classes". `minMoveX/Y/Z`, `maxMoveX/Y/Z`, `speedZoomMaxFOV`, `speedZoomMaxSpeed` are **not** described on the reference page (undocumented there) but are present in every vanilla `ViewPilot`; the "Head Range Plus – TrackIR Mod" changes them per vehicle to give "6 degrees of freedom to first person view when in vehicles", so they are the head-translation limits used by TrackIR / Ctrl+Numpad head shift. Confidence: High (angles/FOV), Medium (move limits meaning).

Vanilla values (config dump of `B_Heli_Light_01_F`, MH-9 Hummingbird):

```
class ViewPilot {
  initAngleX = -3;  minAngleX = -65;  maxAngleX = 85;
  initAngleY = 0;   minAngleY = -150; maxAngleY = 150;
  initFov = 0.9;    minFov = 0.25;    maxFov = 1.25;
  minMoveX = -0.2;  maxMoveX = 0.2;
  minMoveY = -0.1;  maxMoveY = 0.1;
  minMoveZ = -0.1;  maxMoveZ = 0.2;
  speedZoomMaxFOV = 0; speedZoomMaxSpeed = 1e10;
};
```
`B_Heli_Attack_01_F` (AH-99) is identical except `initAngleX = -4`. The engine-wide `ViewCargo` default (base class dump): angles ±85/±150, `initFov 0.75`, `minFov 0.25`, `maxFov 1.25`, all move limits 0. Interpretation (Medium): X = pitch (positive up), Y = yaw, so the pilot can freelook 150° each side and pitch −65..+85; FOV 0.25 is the zoomed-in limit, 1.25 zoomed out. A scripted camera that wants to feel like the vanilla view should replicate these clamps and `initFov`.

Other camera-related vehicle params (verbatim from the reference):

- `HeadAimDown` — "Float: Default: 0. How much to tilt the driver's head forward in degrees." (static; MH-9/AH-99 use 0)
- `driverForceOptics` — "Determines if the driver can freely look around inside the vehicle or if he is locked to looking forward through the hatch/optics." (MH-9/AH-99: 0)
- `viewDriverInExternal` / `viewGunnerInExternal` — "Show the driver in third person view" (Boolean, default false)
- `castDriverShadow`, `viewDriverShadow`, `viewCargoShadow` — shadow rendering in the respective views
- `memoryPointsGetInDriver` / `...Dir` / `...Precise` — get-in points (MH-9: `"pos driver"`, `"pos driver dir"`, `"GetIn_Pilot"`)
- `memoryPointDriverOptics` (MH-9: `"slingCamera"`), `driverOpticsModel`
- Undocumented on the reference page but present in the MH-9 dump: `memoryPointPilot = "pilot"` (see Q4 for use)

#### extCameraPosition[] and extCameraParams[] (third person)

Verbatim from the CfgVehicles Config Reference:

```
extCameraPosition[]
float Array:  { X, Z, Y }; Default { 0, 2, -20 };
External (third-person) camera offset relative to the vehicle's aimpoint memory point, around which the camera orbits.
extCameraPosition[] = { 0, 5, -30 };            // plane
extCameraPosition[] = { 0, 1, -10 };            // cars
extCameraPosition[] = { 0, 1.500000, -9 };      // tanks
extCameraPosition[] = { 0, 0.300000, -3.500000 };  // man

extCameraParams[]
float Array: Default { 0.5, 10, 50, 0.5, 1, 10, 30, 0, 1 };
Smoothing of external camera movement
extCameraParams[] = { multFactor, speedMin, speedMax, factorSpeeedMin, factorSpeeedMax, heightMin, heightMax, factorHeightMin, factorHeightMax };
factor = multFactor * interpolate(speed, speedMin, speedMax, factorSpeeedMin, factorSpeeedMax) * interpolate(heightAGL, heightMin, heightMax, factorHeightMin, factorHeightMax)
factor == 0 -> camera follow horizon
factor == 1 - > camera follow vehicle heading
factor (0, 1) interpolation between horizon and vehicle heading
extCameraParams[] = { 0.5, 10, 50, 0.5, 1, 10, 30, 0, 1 };  // helicopters & UAV
to force the old external camera behavior
extCameraParams[] = { -1 }
```

Vanilla values from the class dumps: base class (`All`) `extCameraParams[] = {1}`, `extCameraPosition[] = {0,2,-20}`; MH-9 `extCameraParams[] = {-1}`, `extCameraPosition[] = {0,2,-15}`; AH-99 `extCameraParams[] = {-1}`, `extCameraPosition[] = {0,2,-20}`. A third-party mod example: `extCameraParams[] = {0.5, 10, 125, 1, 0.2, 1, 5, 1, 0}; extCameraPosition[] = {0.5, 1, -5};` (Legion Studios speeder bike).

History (Steam discussion, May 2017): BI developer "exepowered": "It's been caused by external camera unification so the camera follows vehicle also in pitch. Which is awesome for airplanes, but for helicopters it has reduced the awareness when landing." — then on May 30 2017: "Camera is fixed." User "Hackwell" posted the `extCameraParams` structure and factor semantics in that thread. The thread does not give a version number; this is the 1.70 timeframe.

Does the vanilla third-person helicopter camera bank with the aircraft? The config semantics ("factor 0 -> camera follow horizon") plus the developer's statement that unification made the camera "follow vehicle also in pitch" imply the pre-unification camera — which is what `{-1}` restores and what vanilla helicopters use — keeps the horizon level and follows heading only. Confidence: Medium; roll behaviour specifically is not spelled out anywhere → T13. Related Biki note on `camSetRelPos`: "The camera does not bank with the target (bug?)" — scripted cameras never inherit roll from a target either.

#### Any runtime decoupling / re-orientation of the built-in camera?

None found. Checked: the full "Command Group: Camera Control" listing (68 entries) and every "Introduced with Arma 3 version 2.10/2.12/2.14/2.16/2.18/2.20/2.22" category. Relevant entries and why they do not help:

- `switchCamera` — only selects `"INTERNAL"/"GUNNER"/"EXTERNAL"/"GROUP"/"CARGO"` on a target object.
- `addCamShake` / `setCamShakeParams [posCoef, vertCoef, horzCoef, bankCoef, interpolation]` — "bankCoef: Number - strength of camera tilt/bank, practical range: 0..20". Proves the engine camera *can* be banked by the shake system, but only as a decaying oscillation.
- `setHorizonParallaxCoef` — "Sets coef used to shift horizon position based on camera height".
- `setCameraInterest` — depth-of-field focus weighting for cutscenes.
- `setDefaultCamera` — camera used "after camera is set on no object".
- `lockCameraTo`, `enableDirectionStabilization`, `enableGunStabilization` (2.22) — turret optics only.
- `focusOn` (2.16), `allCameras` (2.18), `screenToWorldDirection` (2.18) — queries only.
- `enableFreeLook` and `getAimDirectionAndUp` — introduced in **2.22** per the category listing; their pages were not retrievable this session (Wayback has no snapshot; live API blocked). Verify syntax in game with `supportInfo "n:enableFreeLook"` / `supportInfo "n:getAimDirectionAndUp"` (T12).
- `camSetBank`, `camSetDive`, `camPrepareBank`, `camPrepareDive`, `camPrepareDir` — Biki: "⚠ This command is non-functional!" (category "Broken Commands"). `camSetDive` note by Kronzky: "Command is non-functional. Instead setVectorUp".

Conclusion (High): the engine's internal camera cannot be offset from script; a scripted camera is required.

### Q2. Scripted camera — command reference

All verbatim from the Biki unless noted.

- **`camCreate`** — `type camCreate position` → Object. "Create a camera or a seagull object on the given position. The creation happens immediately and doesn't wait for camCommit. Among other commands, cameraEffect must be used to enter the camera's view and camDestroy to delete the created camera." Types: `"camera"`, `"seagull"`, `"camconstruct"`, `"camcurator"`, `"crowe"`. Position is PositionAGL. "camCreated objects are only visible locally (meaning they are client-side effects)." Example: `_cam = "camera" camCreate (ASLToAGL eyePos player);`
- **`cameraEffect`** — `camera cameraEffect [effectName, effectPosition, r2tName]`. "Sets the given effect on the given camera. If you want to switch the screen directly to the first-person, aiming, third-person or group view of an object, use switchCamera instead. The effect type "Terminate" is used to exit the current camera view and switch back to the player's view. Does not need camCommit." Effect names: `"Internal"`, `"External"`, `"Fixed"`, `"FixedWithZoom"`, `"Terminate"`; positions `"TOP"`, `"LEFT"`, `"RIGHT"`, `"FRONT"`, `"BACK"`, … "If not sure which position to use, set it to "BACK"." Killzone_Kid's note on the CfgCameraEffects types: `CamExternal (CamInterpolated) type = 0; // linked directly with object`, `CamStatic type = 1`, `CamStaticWithZoom type = 2`, `CamChained type = 3`, `CamTerminate type = 4`, `CamInternal type = 5; // internal view`. On `camSetDir` KK adds: "cameraEffect "INTERNAL" works better than "EXTERNAL" with this command." Important r2t constraint: "One cannot mix and match cameraEffect and can either have multiple r2t cameras or a single camera for the whole screen. If one needs a background stream overlayed with r2t streams, this could be achieved by creating an object and using switchCamera to switch to it for background image, while using cameraEffect for r2t overlay (see Example 4)." Since 1.74 individual r2t sources can be terminated: `cam cameraEffect ["terminate", "back", "rtt1"]`.
- **`cameraEffectEnableHUD`** — "Enable / disable showing of in-game UI during currently active camera effect. By default the HUD is off, which will make results of drawIcon3D invisible, for example." Note (Rebelvg): "Must be executed after camCommit."
- **`camUseNVG`** — "Set / clear using of night vision during cutscenes. This command only works with camCreate created camera that is currently the main camera for the player." Example sequence: `_cam cameraEffect ["Internal","Back"]; _cam camCommit 0; camUseNVG true;`
- **`setCamUseTI`** — `state setCamUseTI modeIndex`. "Sets thermal vision mode for currently used camera. This command only works with camCreate created camera that is currently the main camera for the player." Modes 0 White Hot, 1 Black Hot, 2 Light Green Hot/Darker Green cold, 3 Black Hot/Darker Green cold, 4 Light Red Hot/Darker Red Cold, 5 Black Hot/Darker Red Cold, 6 White Hot/Darker Red Cold, 7 Thermal (Shade of Red and Green, Bodies are white).
- **`camSetFov`** — "Set the zoom level (Field Of View) of the given camera. The zoom level is from 0.01 for the nearest and 8.5 for the furthest zoom value, with a default zoom level of 0.75. The angle of the field of view is atan(FOV)*2 radians when in 4:3 aspect ratio. Needs the call of camCommit to be conducted." **`camPrepareFov`** — same, "The default zoom level is 0.75, 0.01 is the nearest and 2 the furthest", needs `camCommitPrepared`.
- **`camSetPos`** — `camera camSetPos position` (PositionAGL). "It is worth mentioning that camera position can also be set with setPos, in which case it would be instant. With camSetPos it is possible to make smooth position transition in time, defined with camCommit, which is required in this case."
- **`camSetTarget`** — object or position; "Needs the call of camCommit to be conducted. To reset the target use objNull."
- **`camSetDir`** — "Sets the orientation of the given camera in the direction of the given vector. Needs camCommit." Parameter: "Number (before 0.50) - camera azimuth; Array in format [x,y,z] (since 0.50) - direction of camera. Must be a valid vector."
- **`camSetBank`** / **`camSetDive`** — "Sets camera bank angle. Does not commit changes. ⚠ This command is non-functional!" (See also: `setVectorUp`.)
- **`camCommit`** — "Smoothly conduct the changes that were assigned to a camera within the given time. If the time is set to zero, the changes are done immediately." **`camCommitPrepared`** — same for `camPrepareXXX`. **`camCommitted`** — "true if the last camCommit already finished".
- **`camDestroy`** — "⚠ Destroying camera object does not terminate camera effect automatically, use cameraEffect prior to deleting the camera": `_cam cameraEffect ["terminate","back"]; camDestroy _cam;`
- **`camCommand`** — `"manual on"/"manual off"`, `"inertia on"/"inertia off"` for `"camera"` type (immediate, no commit).
- **`showCinemaBorder`** — "Forces drawing of cinema borders when using custom camera camCreate." Note (Crowe): "This command does only work when Mission is started. Use waitUntil {time > 0}".
- **`allCameras`** (2.18) — returns `[camera, r2tInfos, isPrimary, effectName, viewMode, TIindex]`; "viewMode: 0 = normal, 1 = NVG, 2 = TI, 3 = NVG + TI". Useful for debugging which camera is primary and its NV/TI state.
- **`setPiPEffect`** — render-target effects `[0]` normal, `[1]` NV, `[2]` TI, `[3, …]` colour correction, `[7]`,`[8]`, 2.10 `[9..70]`.

**Do generic transform commands work on camera objects?** Yes:

- `setVectorDirAndUp` — Biki description: "Sets orientation of an object. The command takes 2 vector arrays, one for vectorDir and one for vectorUp… When attaching object to an object the axes are relative to the object that gets the attachment… The setDir command is incompatible with setVectorDirAndUp". Note by Str (2008): "Command can be also used to rotate camera in all three axis (which also mean it is possible to set camera bank)." Same note appears on `setVectorUp` and `setVectorDir`. Documented yaw/pitch/roll recipe:
  ```sqf
  _yaw = 45; _pitch = -80; _roll = 0;
  _myObject setVectorDirAndUp [
      [sin _yaw * cos _pitch, cos _yaw * cos _pitch, sin _pitch],
      [[sin _roll, -sin _pitch, cos _roll * cos _pitch], -_yaw] call BIS_fnc_rotateVector2D
  ];
  ```
- `setPosASL` / `setPosWorld` — generic object commands (`setPosWorld` "Sets position of an object based on the model's centre position"; `setPosASL` takes PositionASL). Used on cameras in the H-60 mod (`vtx_uh60_flir_camera setPosASL _camPosASL`) and the Domtaro orbital-camera gist (`_camera setPosASL _cameraPos` inside an `"EachFrame"` handler). `camSetPos` page itself says `setPos` on a camera "would be instant".
- `attachTo` — `object1 attachTo [object2, offset, memPoint, followBoneRotation]` (followBoneRotation since 2.02). "All direction commands, such as setDir, setVectorDirAndUp, etc. for an attached object should be used relative to the reference object's direction (i.e. in model space)". Killzone_Kid's `switchCamera` example attaches a camera object to the player and orients it with `setVectorUp [0,0.99,0.01]`; his `setVectorUp` note explains the trick: plain `[0,1,0]` "will stop working as soon as you attach the box to something", use `[0,0.99,0.01]`. Forum thread "How to attach camera to man's head who in vehicle": `_cam attachTo [_unit,[0,0,0],"head"]` works on foot but "the attachment breaks upon entering a vehicle"; suggested `_cam attachTo [(vehicle _unit),…]`. For this mod, attaching is not needed: writing the world transform each frame (approach 1) avoids the model-space complications and the `attachTo` "vector flip beyond 90° pitch" caveat noted by ffur2007slx2_5.

**Per-frame update mechanism.** Biki text:

- Mission EH **`Draw3D`** (0.50): "Runs the EH code each frame in unscheduled environment. Client side EH only (presence of UI). Will stop executing when UI loses focus (Alt+Tab for example). Usually used with drawIcon3D, drawLine3D."
- Mission EH **`EachFrame`** (1.58): "Executes assigned code each frame. Stackable version of onEachFrame."
- **`onEachFrame`**: "Runs given statement every frame in an unscheduled environment… Only one onEachFrame loop can exist at any time… Script suspension is not permitted within onEachFrame scope."
- **`CBA_fnc_addPerFrameHandler`**: `[{code}, delay, args] call CBA_fnc_addPerFrameHandler`; "0 for every frame". Implementation (CBA `XEH_postInit.sqf`): `addMissionEventHandler ["EachFrame", {call FUNC(onFrame)}];` — i.e. CBA PFHs run inside `EachFrame`.
- The Biki does **not** state the ordering of `Draw3D` vs `EachFrame` relative to simulation and rendering. Community practice (H-60 mod: its per-frame camera update runs from a CBA per-frame handler, i.e. `EachFrame`; Domtaro gist: `EachFrame`) shows `EachFrame` is sufficient when combined with `*Visual` reads. Whether `Draw3D` gives a strictly later (render-scope) sample is T5.

**Role of the `*Visual` commands (High):** every `*Visual` page says it returns data "in render time scope" (`getPosASLVisual`: "Returns an object's rendered ASL position (z value above sea level) in render time scope"; `vectorDirVisual`/`vectorUpVisual`/`vectorSideVisual` (2.14): "in world space and render time scope"; `modelToWorldVisual`/`modelToWorldVisualWorld`, `worldToModelVisual`, `vectorModelToWorldVisual` likewise; `getDirVisual`; `selectionPosition` "in render time scope", syntax 3 has `isVisual: Boolean - (Optional, default true) true for Render, false for Simulation time scope`). The non-Visual variants return the simulation-step state, which lags the rendered frame — that is the classic "camera one frame behind the vehicle" jitter. The fix is to build the camera transform exclusively from `*Visual` reads inside a per-frame handler. Forum thread "Jerky Attached Camera Help?" (TymC/wombat50/f2k sel) shows the failure mode of the old approach — `camCommitPrepared 0` inside a `sleep 0.1` loop "zooms in close then pops back every half a second"; the fix there was a much tighter loop. The camera's own position should be written with `setPosASL`/`setPosWorld` (instant) rather than `camSetPos` + `camCommit 0` (queued transition), matching the H-60 and Domtaro implementations.

Documented in-vehicle geometry helpers used by the H-60 mod (verbatim from its `fnc_updateCamera.sqf`):

```sqf
private _camPosASL = hct_vehicle modelToWorldVisualWorld vtx_uh60_flir_camPos;
vtx_uh60_flir_camera setPosASL _camPosASL;
...
private _dir = getPilotCameraDirection _vehicle;
vtx_uh60_flir_camera setVectorDirAndUp [
  _vehicle vectorModelToWorldVisual _dir,
  _vehicle vectorModelToWorldVisual (_dir vectorCrossProduct (_dir vectorCrossProduct [0, 0, -1]))
];
```

`positionCameraToWorld` (verbatim): "Get the world coordinate space (AGL) from a camera-relative position. cameraPos: PositionRelative - relative camera position, format [x, z, y] (X = left-right, Z = below-above, Y = back-front). ⚠ This command has Y and Z axes swapped around". Worldeater: `positionCameraToWorld [5,10,15] == _camera modelToWorld [5,15,10]`. Kronzky: `if ((positionCameraToWorld [0,0,0] distance player)>2) then { hint "3rd person" }`.

### Q3. What a scripted camera breaks for a pilot, and workarounds

| Item | What the sources say | Workaround | Confidence |
|---|---|---|---|
| 2D HUD (crosshair, action menu, vehicle info panel, radar, compass, Custom Info panels) | `cameraEffectEnableHUD`: "By default the HUD is off" during a camera effect; must run after `camCommit`. `showHUD` array syntax controls `[scriptedHUD, info, radar, compass, direction, menu, group, cursors, panels, kills, showIcon3D]`; "info: show vehicle, soldier and weapon info", "panels: show Arma 3: Custom Info", "showIcon3D (2.04): show icons drawn with drawIcon3D even when the HUD is hidden… The icons will also show when custom camera is created and the view is switched to it via switchCamera or cameraEffect provided cameraEffectEnableHUD is enabled." | `cameraEffectEnableHUD true` immediately after `camCommit 0`; then `showHUD` as normal. | High that the 2D UI can be re-enabled; T4 to confirm the vehicle info panel (`RscUnitInfo`) and radar actually appear. |
| Vehicle `class MFD` HUD / HMD symbology (AH-99 etc.) | MFD config reference: "topLeft/topRight/bottomLeft: memory point defining the … position of the HUD… Not used if helmetMountedDisplay = true"; "helmetMountedDisplay: Defines if the HUD is attached to a fixed point of the aircraft or moves with the head of the pilot"; `helmetPosition/helmetRight/helmetDown` vectors "for helmet mounted only". AH-99 config: `helmetMountedDisplay = 1; helmetPosition[] = {-0.0375,0.0375,0.1}; helmetRight[] = {0.075,0,0}; helmetDown[] = {0,-0.075,0}; topLeft = "HUD_top_left"; …; turret[] = {-2}`; MH-9 has `class MFD {}` (empty). **No source states whether the engine draws class MFD when a scripted camera is the primary camera.** The H-60 mod draws its own `cutRsc` overlay while its scripted camera is up, which suggests the vanilla symbology is not usable there. | If it is not drawn: re-create the needed symbology with `drawIcon3D`/`drawLine3D` in `Draw3D` (needs `cameraEffectEnableHUD true` or `showHUD` `showIcon3D`), or use a `cutRsc` overlay. | Low → T4. |
| Cockpit PiP / render-to-texture | `cameraEffect`: "One cannot mix and match cameraEffect and can either have multiple r2t cameras or a single camera for the whole screen." The H-60 code, after terminating its fullscreen camera, re-issues `cameraEffect ["internal","BACK","vtx_uh60_flir_feed"]` with the comment "Fix pip black screen". `allCameras` (2.18) lists every camera and its r2t sources. | Expect vehicle/mod PiP feeds to go black while the fullscreen camera is active; test and, if needed, re-issue their r2t `cameraEffect` on release. | Medium → T7. |
| Freelook (Alt) and TrackIR | The mouse/TrackIR no longer steer the engine view because the engine view is not on screen. The head *pose* may still be readable: `getCameraViewDirection unit` "Returns the direction unit is looking in render time scope… for human player the origin should be taken from player camera position positionCameraToWorld [0,0,0]"; `eyeDirection` "Returns the direction object is watching (eyes, or a vehicle's primary observer)" (KK: "should have really been named headDirection"). Whether either still tracks the pilot's freelook/TrackIR head while a `cameraEffect` camera is primary is **undocumented**. `positionCameraToWorld` almost certainly follows the *scripted* camera when it is active: the H-60 mod calls `AGLToASL positionCameraToWorld [0,0,0]` / `[0,0,5000]` while in its scripted camera to get that camera's aim ray. Input side: `inputAction` "is capable of returning the state of analog inputs. This includes mouse, joystick, and even TrackIR. A joystick axis will return a value from 0 to 1, while mouse movement returns the rate of change, which can be > 1." (Waffle SS.) but "does not return the actual state of the queried key when a dialog screen is open" (FlannelMouth). H-60 author's comment in `fnc_scriptedCamera.sqf`: "Vanilla user actions do not fire (and inputAction reads 0) while a cameraEffect camera is active, so hook the raw input and map it through the player's actual binding for the lock action. Mouse buttons appear in actionKeys as 65536 + button" — yet the same mod polls `inputAction "zoomIn"/"zoomOut"/"cameraVisionMode"/"nextWeapon"/"defaultAction"` inside the scripted camera, so at least some `inputAction` reads work there. | Reimplement look: poll `inputAction "lookAround"` (Left Alt) / `"lookAroundToggle"` (2×Left Alt) for the freelook modifier, integrate the analog axes `"lookLeftCont"`/`"lookRightCont"`/`"lookUpCont"`/`"lookDownCont"` (default bindings "Tracking device Rot Left/Right/Up/Down"), `"lookShiftLeftCont"` etc. ("Tracking device Left…" translations), `"lookRollLeftCont"/"lookRollRightCont"`, `"lookCenter"` (Num 5), `"lookShiftCenter"` (Ctrl+Num 5); clamp to the vehicle's `ViewPilot` limits. Fallback for anything `inputAction` returns 0 for: `findDisplay 46 displayAddEventHandler ["KeyDown"/"MouseMoving"/"MouseButtonDown", …]` and compare with `actionKeys "lookAround"` (the H-60 pattern). Alternatively, if T2 shows `getCameraViewDirection player` still follows the head, use it directly as the freelook offset — simplest by far. | Medium for the input-action names (High that they exist), Low for behaviour under a scripted camera → T2, T3. |
| Zoom (RMB hold, Num +/−) | Actions: `"zoomTemp"` "Zoom Temporary – Hold Sec. Mouse Btn.", `"zoomIn"`/`"zoomOut"` (Num +/−), `"zoomInToggle"`/`"zoomOutToggle"`, `"zoomContIn"`/`"zoomContOut"` ("Tracking device -tZ"), `"opticsTemp"` (RMB). `inputAction` note: "Right mouse click is currently not supported, but right mouse hold is" — fine for `zoomTemp`. `getObjectFOV` "Returns Field of View of the given object in radians… for units it queries unit weapon optics/zoom, for vehicles - vehicle optics/zoom… doesn't change if user has custom FOV set in profile." | Map the actions to `camSetFov` between the vehicle's `minFov`/`maxFov` (0.25–1.25 on vanilla helis, `initFov` 0.9), `camCommit 0` (or a short commit for smoothing). Check T14 whether `getObjectFOV (vehicle player)` mirrors the engine's zoom state so it can be copied instead of re-implemented. | High (names), Low (getObjectFOV under scripted camera). |
| Night vision / thermal | `camUseNVG` and `setCamUseTI` only affect a `camCreate` camera that is the main camera; the pilot's N key toggles the *unit's* vision mode, which fires object EH `VisionModeChanged` (2.08): `params ["_person","_visionMode","_TIindex","_visionModePrev","_TIindexPrev","_vehicle","_turret"]`; `currentVisionMode [entity]` (2.08) returns `[mode, FLIRindex]`; `allCameras` exposes the primary camera's `viewMode`/`TIindex`. The H-60 mod mirrors vision changes onto its scripted camera from `VisionModeChanged` when `cameraView == "GUNNER"`. | Add `player addEventHandler ["VisionModeChanged", …]` → `camUseNVG (_visionMode == 1)`; `(_visionMode == 2) setCamUseTI _TIindex`. Also poll `inputAction "nightVision"` if the EH proves insufficient. | Medium → T8. |
| Vehicle controls while camera is active | CineCam thread (Xorberax, infantry third-person replacement) chose `switchCamera` over `cameraEffect` because "player loses control of character when using cameraEffect at the moment". Camera Tutorial: "A cinematic camera is what is commonly known as a "cutscene"; the player's input are dismissed". Counter-evidence: the H-60 mod runs `cameraEffect ["Internal","BACK"]` full-screen for a *seated helicopter crew member* (copilot) and keeps other vehicle inputs working. No source covers the flying pilot. | If flight input is lost under `cameraEffect`, use the `switchCamera` proxy-object technique (KK's `switchCamera` note: hidden `Land_HandyCam_F` attached to the vehicle and oriented with `setVectorUp`/`setVectorDirAndUp`), which keeps a normal view mode active. | **Low → T1 (blocking test).** |
| Cinema borders | `showCinemaBorder false` after mission start (`waitUntil {time > 0}`). H-60 calls it right after `camCommit 0`. | Same. | High. |
| Sound / audio listener | No Biki statement found. | Test whether the listener follows the scripted camera; in first person the offset is centimetres so it should be inaudible; matters for third person. | Low → T9. |
| Death / eject / get-out while active | Object EHs (unit-side, persist on respawn "if assigned where unit was local"): `GetOutMan` `params ["_unit","_role","_vehicle","_turret","_isEject"]` (isEject since 2.14, "true if unit used 'Eject' action"), `GetInMan`, `SeatSwitchedMan`, `Killed` `params ["_unit","_killer","_instigator","_useEffects","_shot","_real"]` (local), `Respawn` `params ["_unit","_corpse"]`. Vehicle-side: `GetOut` (with isEject), `Killed`. Mission EHs: `EntityKilled`, `PlayerViewChanged` (1.66) "Fired on player view change. Player view changes when player is changing body due to teamSwitch, gets in out of a vehicle or operates UAV" with `["_oldUnit","_newUnit","_vehicleIn","_oldCameraOn","_newCameraOn","_uav"]`. Release order matters: "Destroying camera object does not terminate camera effect automatically" → always `_cam cameraEffect ["terminate","back"]` then `camDestroy _cam`. | Release in `GetOutMan`, `SeatSwitchedMan` (if no longer driver), `Killed`, vehicle `Killed`, and as a safety net poll `alive player && driver objectParent player == player` each frame. H-60 additionally releases on the CBA player EHs `"unit"`, `"vehicle"`, `"featureCamera"` (Zeus/splendid camera) and on map open (`addUserActionEventHandler ["showMap","Activate",…]`). | High (EH names/params), Medium (ordering) → T10. |

**What the query commands return while a scripted camera is active** (summary; only `positionCameraToWorld` has direct evidence):

- `positionCameraToWorld` → the active (scripted) camera. Evidence: H-60 uses it inside the scripted camera to derive that camera's ray. Medium.
- `getCameraViewDirection player`, `eyeDirection player` → per-unit head direction; unknown whether still driven by mouse/TrackIR when the engine view is not primary. Low → T2.
- `cameraView` → "Returns mode of active camera view… "INTERNAL" (1st person), "EXTERNAL" (3rd person), "GUNNER" (optics / sights), "GROUP" (commander view)". The H-60 code tests `vtx_uh60_flir_isInScriptedCamera || cameraView == "GUNNER"` as two separate conditions, implying `cameraView` keeps reporting the *engine* mode while a scripted camera is up. Low → T6.
- `cameraOn` → "Returns the vehicle to which the camera is attached"; `focusOn` (2.16) → "the person the camera is focused on". Whether they change to the camera object is untested → T6.
- `cameraInterest` → DOF weighting number only; irrelevant.
- `getObjectFOV` → object-level FOV; see zoom row → T14.
- `allCameras` (2.18) → authoritative: `isPrimary` flags which camera is on screen.

**TrackIR from script:** the Biki `TrackIR` page is general information only ("can track the user's head movements in full 6DOF… Armed Assault, Arma 2, Arma 3 and Take On Helicopters all support this device"); there is no head-pose command. The only script-visible channels are (a) the analog input actions above, whose default bindings are literally "Tracking device Rot Left/Right/Up/Down", "Tracking device Left/Right/Up/Down/Forward/Back", "Tracking device -tZ", read through `inputAction`, and (b) possibly `getCameraViewDirection`/`eyeDirection` (T2). H-60 issue #437 confirms in vanilla that "TrackIR is on… head moves along with mouse" is engine seat behaviour they could not disconnect.

**Input-action names (from `inputAction/actions`, with default keys):** `lookAround` "Look" (Left Alt); `lookAroundToggle` "Freelook" (2×Left Alt); `lookUp/lookDown/lookLeft/lookRight/lookLeftUp/lookRightUp/lookLeftDown/lookRightDown` (numpad); `lookCenter` "Center Look" (Num 5); `lookLeftCont/lookRightCont/lookUpCont/lookDownCont` "Look … (Analog)" (Tracking device Rot …); `lookShiftUp/Down/Forward/Left/Right/Back`, `lookShiftCenter` "Center Head Move" (Ctrl+Num 5), `lookShift…Cont` "Head … (Analog)" (Tracking device …); `lookRollLeft/lookRollRight` "Head Roll Left/Right" (Ctrl+Num 7/9) and `…Cont`; `zoomTemp` (Hold RMB); `zoomIn/zoomOut` (Num +/−); `zoomInToggle/zoomOutToggle`; `zoomContIn/zoomContOut` (Tracking device −tZ); `personView` "Toggle View" (Num Enter); `opticsTemp` (RMB); `nightVision` (N); `pilotCamera` "Targeting Camera" (Ctrl+RMB); `vehLockTurretView` (Ctrl+T). There is no `"HeadTrackLeft"` action; the head-tracking axes are the `…Cont` actions. `actionKeys "lookAround"` returns the DIK codes for `KeyDown` matching (mouse buttons are `65536 + button`; Commy2 warns modifier-combo codes are not reliably comparable because of float precision).

### Q4. Geometry and state

**Pilot eye/head position in vehicle model space.**

- `eyePos object` — "Returns the object's eyes / main turret position" (PositionASL). Convert: `(vehicle player) worldToModelVisual (ASLToAGL eyePos player)`. Whether it includes head translation (TrackIR/Ctrl+Num shift) while seated is untested (T11).
- `positionCameraToWorld [0,0,0]` — the actual first-person camera position (AGL) *before* the scripted camera is enabled; sample it once at activation and convert with `worldToModelVisual` to get the exact engine eye point in model space, then re-apply it each frame with `modelToWorldVisualWorld` (ASL) as the H-60 mod does with its camera offset. This is the most faithful method because it already includes `ViewPilot` init offsets. (Medium.)
- `selectionPosition` — "Returns selection position in model space pertaining to the current animation in render time scope"; syntax 2 `object selectionPosition [selectionName, LOD, returnMode]` with LOD `"Memory"`, `"Geometry"`, `"FireGeometry"`, `"LandContact"`, `"HitPoints"`, `"ViewGeometry"` (2.06); syntax 3 adds `isVisual`. Vanilla MH-9 config has the undocumented `memoryPointPilot = "pilot"`, so `_veh selectionPosition ["pilot","Memory"]` is worth trying; if it returns `[0,0,0]` "selection does not exist". The `camPreload` example shows the unit-side memory point `player selectionPosition "camera"`. No `getEyePos` command exists (Biki 404).
- `ViewPilot` `minMove*/maxMove*` bound how far the head may translate from that point (±0.2 m X, −0.1/+0.1 Y, −0.1/+0.2 Z on vanilla helicopters).

**Pitch/bank.** `BIS_fnc_getPitchBank`: "Returns the pitch and bank of an object, in degrees… Pitch is 0 when the object is level; 90 when pointing straight up… Bank is 0 when level; 90 when the object is rolled to the right, -90 when rolled to the left, and 180 when rolled upside down. ⚠ The bank returned by this command is not fully accurate, it can be off by up to 5% or so (depending on pitch) due to an unknown bug." For camera work use the render-scope basis directly: `vectorDirVisual`, `vectorUpVisual`, `vectorSideVisual` (2.14). Vehicle roll angle = `acos ((vectorUpVisual _veh) vectorCos [0,0,1])` restricted by side sign; heading-only forward vector = `vectorNormalized [(vectorDirVisual _veh) select 0, (vectorDirVisual _veh) select 1, 0]` (KK's `vectorDir` note: `[sin _azimuth * cos _altitude, cos _azimuth * cos _altitude, sin _altitude]`). Levelled camera basis: `_dir = _headingVec` (optionally rotated by the freelook yaw/pitch), `_up = [0,0,1]` re-orthogonalised as `_dir vectorCrossProduct (_dir vectorCrossProduct [0,0,-1])` (the H-60 idiom). For the "drag beyond N degrees" rule, compute the angle between the vehicle's up (or dir) and the levelled up (or dir); when it exceeds N, slerp/rotate the levelled basis toward the vehicle basis by (angle − N). (Design inference, not from a source.)

**Detecting that the player is piloting a helicopter.**

- `objectParent player` — Biki: "Use objectParent instead of vehicle to get a soldier's vehicle. Apart from being faster it is also more reliable, as when used on dead crew, vehicle command may surprisingly return the unit itself."; `_isOnFoot = isNull objectParent player`.
- `driver _veh` — "Returns the driver of a vehicle"; example `driver vehicle player isEqualTo player // check if player is driver of current vehicle`.
- `_veh isKindOf "Helicopter"` — vanilla tree `Helicopter_Base_F → Helicopter → Air`; "This command can be used on the whole hierarchical class tree".
- Events: unit-side `GetInMan` `["_unit","_role","_vehicle","_turret"]` ("role: "driver", "gunner", "commander" or "cargo""; "triggered by moveInXXXX commands and "GetInXXXX" actions"), `GetOutMan` (with `_isEject`), `SeatSwitchedMan` `["_unit1","_unit2","_vehicle"]` ("The new position can be obtained with assignedVehicleRole"); mission EH `PlayerViewChanged` for body/vehicle/UAV changes; `TurnIn`/`TurnOut` (vehicle-side) if turned-out crew matter.

**Current view mode and changes.** `cameraView` returns `"INTERNAL"`, `"EXTERNAL"`, `"GUNNER"`, `"GROUP"`. `target switchCamera mode` sets it ("CARGO": same as "INTERNAL"). There is **no vanilla "camera view changed" event**: `PlayerViewChanged` covers body/vehicle changes only; `OpticsSwitch` (2.10) "Triggers at the start of the camera transition from GUNNER to INTERNAL/EXTERNAL and vice-versa… anytime the right mouse button is pressed and there is a GUNNER view available" and `OpticsModeChanged` (2.10) cover optics only. Practical options: poll `cameraView` each frame (cheap), watch `inputAction "personView"` (Num Enter), or use CBA's polling player event `["cameraView", { params ["_unit","_newView","_oldView"]; … }] call CBA_fnc_addPlayerEventHandler` (used by the H-60 mod; also `"vehicle"`, `"featureCamera"`, `"unit"`, `"visibleMap"`).

**Death / destruction.** `Killed` on the unit and on the vehicle (local-argument EH), `EntityKilled` mission EH `["_unit","_killer","_instigator","_useEffects"]`, `HandleDamage` if you want to react before death, `Respawn` `["_unit","_corpse"]` on the new body. Because `Killed` is local and `GetOutMan` persists on respawn only "if assigned where unit was local", add the unit-side EHs on the client to `player` and re-add on `Respawn`.

---

## (c) Confidence per finding (roll-up)

| Finding | Confidence |
|---|---|
| No config/command re-orients the engine ViewPilot camera at runtime (full Camera Control group + 2.10–2.22 categories checked) | High |
| `camSetBank`/`camSetDive`/`camPrepareBank`/`camPrepareDive`/`camPrepareDir` are non-functional | High (Biki banner) |
| `setVectorDirAndUp`/`setVectorUp` set camera roll; `setPosASL`/`setPosWorld` work on camera objects | High (Biki notes + two working codebases) |
| `cameraEffect ["Internal","BACK"]` + per-frame `setPosASL` + `setVectorDirAndUp` from `*Visual` reads is stable at helicopter speeds | High (shipping H-60 mod) |
| `*Visual` commands = render-time scope; needed to avoid one-frame lag | High (Biki) |
| `EachFrame` vs `Draw3D` ordering relative to render | Not documented → test |
| `extCameraParams[]` semantics and `{-1}` on vanilla helicopters | High (Biki reference + config dump) |
| Vanilla third-person heli camera keeps horizon level | Medium |
| `cameraEffectEnableHUD` restores 2D UI; must follow `camCommit` | High |
| class MFD/HMD symbology drawn under a scripted camera | Unknown → test |
| PiP/r2t feeds disrupted by a fullscreen `cameraEffect` | Medium |
| `positionCameraToWorld` follows the scripted camera when active | Medium |
| `getCameraViewDirection`/`eyeDirection` still track freelook/TrackIR under scripted camera | Unknown → test |
| `inputAction` look/zoom action names | High; behaviour under scripted camera Medium/Low |
| No script API for TrackIR pose except analog input actions | High |
| Pilot keeps flight controls under `cameraEffect` | Unknown → blocking test |
| `switchCamera` proxy-object alternative | Medium |
| Eye position via `positionCameraToWorld [0,0,0]` → `worldToModelVisual` | Medium; `eyePos` in-seat behaviour Low; `"pilot"` memory point Low |
| `BIS_fnc_getPitchBank` bank error up to ~5% | High (Biki) |
| EH names/params for get-in/out/seat/kill/respawn/view change | High |
| No vanilla camera-view-changed event; CBA `"cameraView"` player EH or polling | High |
| `enableFreeLook` / `getAimDirectionAndUp` (2.22) exist | High (category listing); semantics unknown |

---

## (d) Things only in-game testing can resolve

Set up a test mission with a vanilla MH-9 (no MFD) and an AH-99 (HMD MFD), a debug console, and a simple `EachFrame` loop that prints the values below with `hintSilent`.

- **T1 (blocking) Flight control under `cameraEffect`.** Enter `cameraEffect ["Internal","BACK"]` on a camera parked at the pilot's eye while flying. Check collective/cyclic/pedals on keyboard, joystick and mouse-cyclic profile; check engine on/off, gear, landing autohover, weapon fire (`defaultAction`), targeting keys. Repeat with the `switchCamera` proxy-object technique (hidden `Land_HandyCam_F` attached to the vehicle). Record which inputs die in each mode.
- **T2 Head pose under the scripted camera.** While the scripted camera is primary, freelook (Alt) and move the mouse / TrackIR; print `getCameraViewDirection player`, `eyeDirection player`, `positionCameraToWorld [0,0,0]`, `positionCameraToWorld [0,0,1]`. Expected: `positionCameraToWorld` follows the scripted camera; determine whether the other two still follow the head. If yes, freelook can be reused as-is.
- **T3 `inputAction` reads under the scripted camera.** Print `inputAction "lookAround"`, `"lookAroundToggle"`, `"lookLeftCont"`, `"lookUpCont"`, `"lookShiftLeftCont"`, `"zoomTemp"`, `"zoomIn"`, `"zoomOut"`, `"nightVision"`, `"personView"` each frame with mouse, joystick and TrackIR; note value ranges (mouse returns rate-of-change) and any that read 0 only inside the camera (the H-60 author reports this for `vehLockTurretView`). Also test the `findDisplay 46` `KeyDown`/`MouseMoving` fallback.
- **T4 HUD rendering.** With `cameraEffectEnableHUD true` after `camCommit 0`, check: 2D vehicle info panel (`showHUD` "info"), radar/compass, Custom Info panels, action menu; and on the AH-99 whether the class MFD HMD symbology (horizon bar, heading tape, gun cross) is drawn at all, and if so whether it stays aligned when the camera is levelled but the airframe rolls (the HMD is anchored to the pilot head via `helmetPosition/helmetRight/helmetDown`).
- **T5 Per-frame handler choice and jitter.** Implement the update in (a) `addMissionEventHandler ["EachFrame",…]`, (b) `["Draw3D",…]`, (c) `CBA_fnc_addPerFrameHandler` 0. Fly at 250 km/h with rapid rolls; compare `getPosASLVisual` vs `getPosASL` deltas and look for cockpit geometry "swimming" relative to the camera. Also compare `setPosASL`+`setVectorDirAndUp` against `camSetPos`/`camSetDir`+`camCommit 0`.
- **T6 View-mode queries under the scripted camera.** Print `cameraView`, `cameraOn`, `focusOn`, `allCameras` and check what changes when the player presses Num Enter or RMB (does `OpticsSwitch` still fire?). Decide whether polling `cameraView` or `inputAction "personView"` is the reliable trigger to swap between first- and third-person scripted modes.
- **T7 PiP/r2t interaction.** Use a vehicle with a PiP display (e.g. a modded heli with MFD feeds, or vanilla vehicles with mirrors) and check whether feeds go black while the fullscreen camera is active and whether they recover after `cameraEffect ["terminate","back"]` (the H-60 mod had to re-issue the r2t `cameraEffect`).
- **T8 NVG/TI mirroring.** Press N while the scripted camera is active; confirm `VisionModeChanged` fires and that `camUseNVG`/`setCamUseTI` applied from that EH match the engine's own vision mode; check `allCameras` `viewMode`.
- **T9 Audio listener.** In third-person scripted mode, fly past a sound source and check whether stereo panning follows the camera or the pilot's head.
- **T10 Release ordering.** Eject, get out on the ground, switch seats, die in the air, and vehicle destruction with the camera active; confirm `GetOutMan`/`SeatSwitchedMan`/`Killed` ordering versus `PlayerViewChanged`, that `cameraEffect ["terminate","back"]` before `camDestroy` always returns a sane view, and behaviour after respawn (re-add unit EHs on `Respawn`).
- **T11 Eye position sources.** Compare `eyePos player`, `positionCameraToWorld [0,0,0]`, `_veh selectionPosition ["pilot","Memory"]` and the `ViewPilot` head-shift range while shifting the head with Ctrl+Numpad and TrackIR; pick the model-space anchor.
- **T12 New 2.22 commands.** In the debug console run `supportInfo "n:enableFreeLook"` and `supportInfo "n:getAimDirectionAndUp"` to get their syntax; check whether `enableFreeLook` can be used to force freelook on so head input keeps flowing into T2's queries.
- **T13 Third-person baseline and config knob.** In vanilla external view, roll the MH-9 hard and note whether the camera rolls/pitches with it (`extCameraParams[] = {-1}`); then patch `extCameraParams[]` (e.g. `{0.5,10,50,0.5,1,10,30,0,1}` and `{0}`) and observe pitch and roll behaviour separately. Also check that a scripted third-person camera has no terrain/object collision handling (the engine's external camera does).
- **T14 Zoom mirroring.** Hold RMB / press Num +/− under the scripted camera and print `getObjectFOV (vehicle player)` and `getObjectFOV player`; if either tracks the engine zoom, drive `camSetFov` from it instead of re-implementing the zoom curve (`ViewPilot` `initFov 0.9`, `minFov 0.25`, `maxFov 1.25`).
- **T15 Cinema border and HUD timing.** Confirm `showCinemaBorder false` and `cameraEffectEnableHUD true` behave when issued in the same frame as `camCommit 0` at mission start (`time > 0`).

---

## (e) Sources

Bohemia Interactive Community Wiki (Biki). Pages marked (WB) were read from Wayback Machine snapshots because the live site returned HTTP 403 for this session; snapshot dates in parentheses. Pages marked (API) were read as live wikitext through `https://community.bistudio.com/wikidata/api.php`.

- https://community.bistudio.com/wiki/camCreate (API)
- https://community.bistudio.com/wiki/cameraEffect (WB 2025-03-20)
- https://community.bistudio.com/wiki/cameraEffectEnableHUD (WB 2021-03-08)
- https://community.bistudio.com/wiki/camUseNVG (WB 2025-04-19)
- https://community.bistudio.com/wiki/setCamUseTI (WB 2025-01-21)
- https://community.bistudio.com/wiki/camSetFov (WB 2025-03-04)
- https://community.bistudio.com/wiki/camPrepareFov (WB 2025-02-11)
- https://community.bistudio.com/wiki/camSetPos (WB 2025-02-11)
- https://community.bistudio.com/wiki/camSetTarget (WB 2025-03-19)
- https://community.bistudio.com/wiki/camSetBank (WB 2025-01-21)
- https://community.bistudio.com/wiki/camSetDir (WB 2025-02-12)
- https://community.bistudio.com/wiki/camSetDive (WB 2021-02-24)
- https://community.bistudio.com/wiki/camCommit (WB 2025-03-25)
- https://community.bistudio.com/wiki/camCommitPrepared (WB 2025-02-14)
- https://community.bistudio.com/wiki/camCommitted (WB 2022-08-16)
- https://community.bistudio.com/wiki/camPreparePos, camPrepareTarget, camPrepareBank, camPrepareDir, camPrepareDive (WB Jan–Mar 2025)
- https://community.bistudio.com/wiki/camSetRelPos (WB 2025-05-25)
- https://community.bistudio.com/wiki/camDestroy (WB 2025-05-24)
- https://community.bistudio.com/wiki/camPreload (WB 2025-02-26)
- https://community.bistudio.com/wiki/camCommand (WB 2025-05-24)
- https://community.bistudio.com/wiki/showCinemaBorder (WB 2025-03-18)
- https://community.bistudio.com/wiki/showHUD (WB 2025)
- https://community.bistudio.com/wiki/switchCamera (WB 2025-05-24)
- https://community.bistudio.com/wiki/cameraView (WB 2025-03-28)
- https://community.bistudio.com/wiki/cameraOn (WB 2025-02-26)
- https://community.bistudio.com/wiki/cameraInterest (WB 2025-03-28), https://community.bistudio.com/wiki/setCameraInterest (WB 2020-06-03)
- https://community.bistudio.com/wiki/focusOn (WB 2025-01-20)
- https://community.bistudio.com/wiki/allCameras (WB 2025-01-17)
- https://community.bistudio.com/wiki/positionCameraToWorld (WB 2025-02-15)
- https://community.bistudio.com/wiki/getCameraViewDirection (WB 2025-01-15)
- https://community.bistudio.com/wiki/getObjectFOV (WB 2025-02-16)
- https://community.bistudio.com/wiki/lockCameraTo (WB 2025), https://community.bistudio.com/wiki/enableDirectionStabilization (WB 2025-03-09)
- https://community.bistudio.com/wiki/setHorizonParallaxCoef (WB 2025-03-25)
- https://community.bistudio.com/wiki/addCamShake (WB 2025-02-12), https://community.bistudio.com/wiki/setCamShakeParams (WB 2025-05-22)
- https://community.bistudio.com/wiki/setPiPEffect (WB 2025-01-17)
- https://community.bistudio.com/wiki/setDefaultCamera (WB 2025-02-11)
- https://community.bistudio.com/wiki/setVectorDirAndUp (WB 2024-10-08)
- https://community.bistudio.com/wiki/setVectorUp (WB 2025-04-19), https://community.bistudio.com/wiki/setVectorDir (WB 2025-02-10)
- https://community.bistudio.com/wiki/attachTo (WB 2025-01-14), https://community.bistudio.com/wiki/detach (WB 2025-01-21)
- https://community.bistudio.com/wiki/setPosWorld (WB 2025-04-20), https://community.bistudio.com/wiki/setPosASL (WB 2025-03-13), https://community.bistudio.com/wiki/setPos (WB 2024-12-09)
- https://community.bistudio.com/wiki/getPosASLVisual (WB 2025-03-06), getPosWorldVisual (WB 2025-03-20), getPosVisual (WB 2025-03-24), visiblePosition (WB 2025-05-26)
- https://community.bistudio.com/wiki/vectorDirVisual (WB 2025-02-15), vectorUpVisual (WB 2025-02-11), vectorSideVisual (WB 2025-01-16), vectorDir (WB 2025-02-14)
- https://community.bistudio.com/wiki/modelToWorldVisual (WB 2025-01-15), worldToModelVisual (WB 2025-03-17), vectorModelToWorldVisual (WB 2025-03-27)
- https://community.bistudio.com/wiki/selectionPosition (WB 2025-01-17)
- https://community.bistudio.com/wiki/eyePos (WB 2025-02-26), https://community.bistudio.com/wiki/eyeDirection (WB 2025-02-17), https://community.bistudio.com/wiki/aimPos (WB 2025-01-20)
- https://community.bistudio.com/wiki/getEyePos — does not exist (404)
- https://community.bistudio.com/wiki/BIS_fnc_getPitchBank (WB 2025-02-14), https://community.bistudio.com/wiki/BIS_fnc_setPitchBank (WB 2025-01-16)
- https://community.bistudio.com/wiki/getDir (WB 2025-03-18), getDirVisual (WB 2025-03-16)
- https://community.bistudio.com/wiki/isKindOf (WB 2025-04-20), driver (WB 2025-03-26), vehicle (WB 2025-04-19), objectParent (WB 2025-01-16)
- https://community.bistudio.com/wiki/inputAction (WB 2025-04-20)
- https://community.bistudio.com/wiki/inputAction/actions (WB 2025-04-17)
- https://community.bistudio.com/wiki/inputMouse (WB 2025-03-18), https://community.bistudio.com/wiki/inputController (WB 2025-02-15), https://community.bistudio.com/wiki/actionKeys (WB 2025-04-19)
- https://community.bistudio.com/wiki/TrackIR (WB 2025-04-20)
- https://community.bistudio.com/wiki/disableUserInput (WB 2025-04-20), currentVisionMode (WB 2025-04-20), screenToWorldDirection (WB 2024-12-06)
- https://community.bistudio.com/wiki/enableFreeLook and https://community.bistudio.com/wiki/getAimDirectionAndUp — listed in "Category:Introduced with Arma 3 version 2.22" (API) but pages not retrievable this session
- https://community.bistudio.com/wiki/onEachFrame (WB 2025-03-28), https://community.bistudio.com/wiki/addMissionEventHandler (WB 2025-02-14)
- https://community.bistudio.com/wiki/Arma_3:_Mission_Event_Handlers (API) — Draw3D, Draw2D, EachFrame, PlayerViewChanged, EntityKilled
- https://community.bistudio.com/wiki/Arma_3:_Event_Handlers (API) — GetInMan, GetOutMan, GetOut, SeatSwitchedMan, Killed, Respawn, OpticsModeChanged, OpticsSwitch, VisionModeChanged, TurnIn/TurnOut, HandleDamage
- https://community.bistudio.com/wiki/Category:Command_Group:_Camera_Control (API, 68 members) and the categories "Introduced with Arma 3 version 2.10 / 2.12 / 2.14 / 2.16 / 2.18 / 2.20 / 2.22" (API)
- https://community.bistudio.com/wiki/Camera_Tutorial (API), https://community.bistudio.com/wiki/Camera.sqs (API)
- https://community.bistudio.com/wiki/CfgVehicles_Config_Reference (WB 2025-01-24) — ...AngleX/Y, minFov/maxFov, extCameraPosition[], extCameraParams[], HeadAimDown, driverForceOptics, viewDriverInExternal/viewGunnerInExternal, castDriverShadow, memoryPointsGetIn…
- https://community.bistudio.com/wiki/Arma_3:_Multi-Function_Display_(MFD)_config_reference (WB 2024-12-07)
- https://community.bistudio.com/wiki/HUD (WB 2025-01-13)
- https://community.bistudio.com/wiki/Arma_3:_Field_Manual_-_Vehicle_Controls (WB 2025-02-14)

Vanilla config values (GitHub dump of the Arma 3 class tree, read via the GitHub API):
- https://github.com/lukegotjellyfish/Arma-Class-Exporter/blob/master/Exports/SQF-Class-Exports/Arma3/Vehicles/b_heli_light_01_f.py (MH-9: ViewPilot, extCameraParams, extCameraPosition, memoryPointPilot, viewGunnerInExternal)
- https://github.com/lukegotjellyfish/Arma-Class-Exporter/blob/master/Exports/SQF-Class-Exports/Arma3/Vehicles/b_heli_attack_01_f.py (AH-99: MFD/HMD block, ViewPilot, extCamera*)
- https://github.com/lukegotjellyfish/Arma-Class-Exporter/blob/master/Exports/SQF-Class-Exports/Arma3/Vehicles/helih.py (base-class defaults: extCameraParams {1}, ViewCargo, headLimits)
- https://github.com/Legion-Studios/LegionCore-Public/blob/master/addons/vehicles_105k/CfgVehicles.hpp (third-party extCameraParams example)

Working mod code:
- Project Hatchet UH-60 (H-60) — https://github.com/Project-Hatchet/H-60/tree/master/addons/uh60_flir : `functions/fnc_scriptedCamera.sqf`, `functions/fnc_updateCamera.sqf`, `functions/fnc_perFrame.sqf`, `functions/fnc_handleKeyInputs.sqf`, `functions/fnc_setup.sqf`, `functions/fnc_setFOV.sqf`, `functions/fnc_shutDown.sqf`, `initKeybinds.sqf`; issues https://github.com/Project-Hatchet/H-60/issues/538 and /437
- CBA_A3 — https://github.com/CBATeam/CBA_A3/blob/master/addons/common/fnc_addPerFrameHandler.sqf and https://github.com/CBATeam/CBA_A3/blob/master/addons/common/XEH_postInit.sqf ; docs https://cbateam.github.io/CBA_A3/docs/files/common/fnc_addPerFrameHandler-sqf.html
- Domtaro, "[ARMA 3] UAV-like Orbital Camera Moving Script" — https://gist.github.com/Domtaro/db7919b0bd1f4ec12eee51e244c84478
- Cre8or/Conquest `scripts/ui/fn_ui_sys_drawIcons3D.sqf` (`inputAction "lookAround"` usage) — https://github.com/Cre8or/Conquest

Forums / Steam:
- Steam discussion "Changes in helicopter camera/controls?" (developer statement on external camera unification, extCameraParams) — https://steamcommunity.com/app/107410/discussions/0/2741975115083048963/?ctp=2
- Steam discussion "3rd person view perspective changes when flying helicopters" — https://steamcommunity.com/app/107410/discussions/0/1480982338942050419/
- BI Forums "Helicopter camera" (Dev Branch) — https://forums.bohemia.net/forums/topic/204694-helicopter-camera/ (WB 2022-12-06)
- BI Forums "[WIP] CineCam | Cinematic Third-Person Camera Replacement" — https://forums.bohemia.net/forums/topic/220040-wip-cinecam-cinematic-third-person-camera-replacement/ (WB 2024-05-28)
- BI Forums "Jerky Attached Camera Help?" — https://forums.bohemia.net/forums/topic/163131-jerky-attached-camera-help/
- BI Forums "How to Attach Camera to man's head who in vehicle?" — https://forums.bohemia.net/forums/topic/213512-how-to-attach-camera-to-mans-head-who-in-vehicle/
- BI Forums "Triggering free-look via script" — https://forums.bohemia.net/forums/topic/160073-triggering-free-look-via-script/ (WB 2020-06-19; no solution found in thread)
- BI Forums "Is it possible to force a player to toggle freelook?" — https://forums.bohemia.net/forums/topic/174416-is-it-possible-to-force-a-player-to-toggle-freelook/ (WB 2020-06-21; no solution found)
- BI Forums "HUD Class MFD Template...?" — https://forums.bohemia.net/forums/topic/205195-hud-class-mfd-template/ (WB 2020-06-23)
- BI Forums "Helmet Mounted Displays MOD" — https://forums.bohemia.net/forums/topic/170973-helmet-mounted-displays-mod/ (WB 2024-11-13)
- Steam Workshop "Head Range Plus - TrackIR Mod" — https://steamcommunity.com/sharedfiles/filedetails/?id=630737877
- Steam Workshop "Custom Third Person Camera" — https://steamcommunity.com/sharedfiles/filedetails/?id=3745888315
- Steam Workshop "A3R - Third Person Camera Addons" collection — https://steamcommunity.com/sharedfiles/filedetails/?id=2993007436 (WB 2025-11-02)
- Steam guide "Camera/Cinematic Scripting" — https://steamcommunity.com/sharedfiles/filedetails/?id=237739786
- AH-64D mod "Head Tracking Mode" docs — https://ah-64d-apache-official-project.github.io/ui-headtracking.html (UI-level only; no script API)

Not reachable this session (for completeness): Steam GCam stutter discussion https://steamcommunity.com/workshop/filedetails/discussion/909893746/4052614174004810154/ (HTTP 429), Biki `Position` page, Biki `Arma 3: Changelog`.
