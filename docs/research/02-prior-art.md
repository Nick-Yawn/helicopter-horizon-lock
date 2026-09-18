# 02 – Prior art: horizon-locked / stabilized pilot camera for Arma 3

Research date: 2026-09-18. Scope: Arma 3 (Real Virtuality 4, 2013), not Reforger.

Access notes (read before trusting anything below):

- `community.bistudio.com` (BI Wiki) and `forums.bohemia.net` sit behind a Cloudflare bot check that blocked WebFetch, curl, the embedded browser pane and archive/reader proxies. I could pull raw wikitext for a subset of wiki pages through the MediaWiki API (`cameraEffect`, `positionCameraToWorld`, `camSetBank`, `camPrepareBank`, `cameraEffectEnableHUD`, `camCommand`, `camUseNVG`, `cameraView`, `BIS_fnc_camFollow`, `Take On Helicopters: Patches`, `Arma 3: Difficulty Settings`). The pages for `getCameraViewDirection`, `TrackIR`, `inputAction`, `freeLook`, `eyeDirection`, `CfgVehicles Config Reference` and the Field Manual never came through; where I cite them I say so and rely on search-engine snippets or on how open-source mods use the commands.
- BI forum threads: I could read 166030, 193132, 163426, 213512, 225922 (and the NaturalPoint threads). I could NOT read 204694 (dev-branch "Helicopter camera", 15 pages), 220040 (CineCam), 216403 (indiCam), 170973 (HMD mod), 181544 (tank-turret camera), 224139 (3rd person for aircraft). Their content below comes from Steam-thread quotes and the Steam Workshop pages.
- Steam Workshop pages were readable until Steam started returning HTTP 429 late in the session; four small items (Camera Co-Pilot, Switchable Body Camera, Clu's Custom Camera, Cute Cameras) are therefore listed by title only.
- Everything marked "source read" was downloaded from GitHub raw and read in full or grepped; quotes are verbatim.

---

## (a) Summary

**Nothing I could find does exactly this** (a client-side, gameplay-time, horizon-locked / decoupled pilot camera with a deadzone that keeps HUD, freelook/TrackIR, zoom and NVG working). The closest things, in order of relevance:

1. **Vanilla Arma 3 itself, third person only: `extCameraParams[]`** (CfgVehicles, added with the 1.70 "Jets" platform update, May 2017). When BI "unified" the external camera so it follows vehicle pitch, helicopter pilots lost ground visibility on landing; BI's fix was a per-vehicle config array that blends the third-person camera between *horizon-following* and *attitude-following* as a function of speed and height AGL. A developer described the regression as: "It's been caused by external camera unification so the camera follows vehicle also in pitch. Which is awesome for airplanes, but for helicopters it has reduced the awareness when landing." Community member Hackwell then quoted the config reference: `extCameraParams[] = {multFactor, speedMin, speedMax, factorSpeeedMin, factorSpeeedMax, heightMin, heightMax, factorHeightMin, factorHeightMax}; factor == 0 -> camera follow horizon / factor == 1 -> camera follow vehicle heading / factor (0,1) interpolation between horizon and vehicle heading`. Search-engine snippets of the CfgVehicles reference add the formula `factor = multFactor * interpolate(speed, speedMin, speedMax, factorSpeedMin, factorSpeedMax) * interpolate(heightAGL, heightMin, heightMax, factorHeightMin, factorHeightMax)` and the helicopter/UAV default `{0.5, 10, 50, 0.5, 1, 10, 30, 0, 1}`. Real mod configs confirm the field layout (e.g. a Mavic-style drone config uses `extCameraParams[] = {0.93,10,30,0.25,1,10,30,0,1};`; a land-vehicle config uses `{0.5, 10, 125, 1, 0.2, 1, 5, 1, 0}`). This is a **config-only, zero-script way to get a horizon-following 3rd-person helicopter camera** (`multFactor = 0` on `Helicopter` base class), with two caveats: it only governs the *pitch* blend (the vanilla external camera does not bank with the airframe in the first place — every complaint in the threads is about pitch, none about roll), and it does nothing for first person. No workshop mod that ships such a patch turned up; the "helicopter camera" hits on the Workshop are all unrelated (the item Hackwell linked, id 928969898, is his own training scenario, not a camera mod).

2. **Advanced Train Simulator / AI Command "3rd-person camera" (Seth Duda)** – the only open-source example I found of a *scripted chase camera running while the player keeps driving*: an `EachFrame` loop that places a `"camera"` object at a vehicle-relative offset, aims it at the vehicle, and builds the up-vector from world-up so the view stays horizon-level regardless of vehicle attitude; mouse orbit and wheel zoom via display `MouseMoving`/`MouseZChanged` handlers; terminates the camera while the map is open. AIC is MIT; ATS has no license file.

3. **ACE3 spectator, BI End Game spectator, Simple Cinematic Camera (Bro_SimpleCam), Streamator** – production-quality scripted camera loops (all `EachFrame`, all `*Visual` commands, all `cameraEffectEnableHUD true`) that show the mechanics: follow/orbit maths, yaw/pitch/roll to dir+up vectors, per-frame smoothing, vision modes via `camUseNVG`/`setCamUseTI`, input via display event handlers and `inputAction`. None of them is a gameplay camera (the player is a spectator or the target is another unit), and notably ACE3 and BI both **give up on scripting a first-person view**: their "FPS" mode terminates the scripted camera and calls `switchCamera "INTERNAL"` on the unit.

4. **Reading the player's head/freelook direction each frame** exists in three open mods, all while the *engine* camera is active: the AH-64D mod slaves its PNVS turret to `getCameraViewDirection player` transformed by `vectorWorldToModelVisual`; the a3vr-arma3 VR mod reads `getCameraViewDirection player` every frame and re-applies it to two render-to-texture cameras with a *world-up-derived, roll-free basis* (exactly the "keep the pilot's look direction, strip the airframe roll" operation this mod needs); CBA (`CBA_fnc_headDir`) and ACRE (`fnc_getHeadVector`) derive the view vector from `positionCameraToWorld [0,0,0]` and `[0,0,N]`. **No source I found reads head direction while a full-screen `cameraEffect` camera is active and re-applies it to that camera** — whether `getCameraViewDirection`/`positionCameraToWorld` still track freelook/TrackIR in that state is the key unknown and must be tested in-game (a3vr explicitly switches to reading its own proxy camera when a full-screen scripted camera is up, and states "cameraEffect cannot mix a full-screen camera with RTT sources").

5. **CineCam (Zooloo75, 2018)** – the only attempt at a scripted *replacement* for the player's own third-person camera during gameplay. Infantry-only, alpha, abandoned, source not public; Steam comments report it "breaks 3person interactions and vehicle view", motion sickness, and a camera that persisted after uninstall. Useful mainly as a list of pitfalls.

6. **Take On Helicopters**: no evidence of a horizon-stabilized or "free head" camera option. TOH's contribution was airframe-relative 6-DOF head tracking (patch notes: "Head-tracking logic improved: the head position was offset in reverted direction when certain roll limits were reached (looking over shoulder)", "Helicopter head movement limits tweaked", "Zero default value for min/maxMoveX/Y/Z in ViewXXX classes", "TrackIR scheme improved"), which Arma 3 inherited as the `ViewPilot`/`ViewGunner` classes (`minAngleX/maxAngleX`, `minMoveX/Y/Z`, `initFov`...) that mods like Head Range Plus edit. The Arma 3 `extCameraParams` blend is a 2017 Arma 3 addition, not a TOH feature. (TOH manual and TOH forum boards were unreachable; this conclusion is from the TOH patch notes, the TOH TrackIR press coverage and the NaturalPoint threads.)

---

## (b) Catalog

Legend: **Impl** = how it is implemented; **Preserves** = HUD / vehicle MFD / freelook / TrackIR / zoom / NVG-TI / vehicle control while active; **Src** = source availability + license. "—" = not applicable, "?" = could not determine.

### B1. Engine features and config knobs (vanilla)

| Item | What it does for the player | Impl | Preserves | Src |
|---|---|---|---|---|
| `extCameraParams[]` (CfgVehicles, A3 1.70+) | Blends the 3rd-person camera between horizon-following (factor 0) and attitude-following (factor 1) by speed and height AGL. Helicopter/UAV default `{0.5,10,50,0.5,1,10,30,0,1}` (per search snippet of the CfgVehicles reference; page itself blocked). | Config only, per vehicle class | Everything (it is the engine camera) | — |
| `extCameraPosition[]` (CfgVehicles) | Offset of the 3rd-person camera pivot; used by every infantry "over the shoulder" mod. | Config only | Everything | — |
| `ViewPilot`/`ViewGunner`/`ViewOptics` classes (`initAngleX/Y`, `minAngleX/Y`, `maxAngleX/Y`, `initFov/minFov/maxFov`, `minMoveX/Y/Z`, `maxMoveX/Y/Z`) | Head turn/lean limits and zoom range in 1st person; TOH lineage. Quoted in BI thread 163426: `initAngleX = 0; minAngleX = -65; maxAngleX = 85; initAngleY = 0; minAngleY = -150; maxAngleY = 150`. | Config only | Everything | — |
| Difficulty `thirdPersonView` (0/1/2 = vehicles only, since 1.99/2.00), `cameraShake` | Server can restrict 3rd person; a scripted camera bypasses this unless you check it yourself. | — | — | — |
| `pilotcameralock` MFD condition (0 disabled, 1 locked to terrain, 2 locked to objects) | Mentioned by a dev in the 2017 thread; concerns the *pilot targeting camera*, not the view camera. | Config (MFD) | — | — |
| Camera scripting commands | `camCreate` ("camera" / "CamCurator" / "seagull"), `cameraEffect [effect, pos, r2t]` (effects "Internal", "External", "Fixed", "FixedWithZoom", "Terminate"; KK's note: CamExternal=type 0 "linked directly with object", CamStatic=1, CamStaticWithZoom=2, CamChained=3, CamTerminate=4, CamInternal=5), `cameraEffectEnableHUD` ("By default the HUD is off, which will make results of drawIcon3D invisible"; note by Rebelvg: "Must be executed after camCommit"), `camCommand` ("manual on/off" for engine-driven controls; "inertia on/off"; CamCurator-only "maxPitch/minPitch/speedDefault/speedMax/ceilingHeight/atl/surfaceSpeed"), `camUseNVG` ("only works with camCreate created camera that is currently the main camera"), `setCamUseTI`, `camSetFov`, `setVectorDirAndUp`. **`camSetBank` and `camPrepareBank` are documented as "non-functional" (Broken Commands)** — roll must be done via `setVectorDirAndUp`. | — | — | BI Wiki (wikitext read via API) |
| `positionCameraToWorld` | Camera-relative `[x, z, y]` (axes swapped) to AGL; `positionCameraToWorld [0,0,0]` = current camera position; distance to player > 2 m = 3rd person (Kronzky note). | — | — | BI Wiki (read) |
| `getCameraViewDirection`, `freeLook`, `eyeDirection`, `inputAction`, `TrackIR` wiki pages | Blocked. Usage evidence from open mods only (see B4). | — | — | not read |

### B2. Workshop / forum camera mods aimed at the player's own view

| Name | Link | Player-facing behaviour | Impl | Preserves | Src / license |
|---|---|---|---|---|---|
| **CineCam – Cinematic Third-Person Camera Replacement** (Zooloo75, 2018, alpha, abandoned; Workshop item now flagged incompatible/removed) | https://steamcommunity.com/sharedfiles/filedetails/?id=1551751531 ; thread https://forums.bohemia.net/forums/topic/220040-wip-cinecam-cinematic-third-person-camera-replacement/ (blocked) | Replaces infantry 3rd-person camera: centres behind player when weapon lowered, goes over the shoulder when aiming, moves closer in freelook, "weight-based" motion. Options via CBA addon options. | Scripted camera (inferred from behaviour and from complaints that the camera persisted after uninstall); requires CBA; exact loop unknown | Vehicles: **no** — comments: "breaks 3person interactions and vehicle view"; motion sickness; "some features unavailable in third-person mode"; breaks missions that script cameras | Not public (no link found) |
| **X5 Ghost Recon Camera** (X5XFiRE) | https://steamcommunity.com/sharedfiles/filedetails/?id=1284600102 | Over-the-shoulder infantry 3rd person. "No scripts. No performance impact." | Config: `extCameraPosition[]` on `CAManBase` | Infantry only; vehicles untouched | Config visible in PBO; license per page |
| **Custom Third Person Camera** (Division-style) | https://steamcommunity.com/sharedfiles/filedetails/?id=3745888315 | Tighter over-the-shoulder infantry view; "tweak camera values with PBO Manager" | Config `extCameraPosition[]` | Infantry only | Config in PBO |
| **Custom 3rd Person Camera – Reuploaded** | https://steamcommunity.com/sharedfiles/filedetails/?id=2331976670 | Same family | Config | Infantry | ? |
| **Third Person Camera Position Changer** (Mr.Crash) | https://steamcommunity.com/sharedfiles/filedetails/?id=2582295355 | "Infantry only", 1.4 KB, client side; users edit line 19 `extCameraPosition[]={0.3,-0.25,-1.2}` | Config only | Infantry only | No modification without written permission |
| **A3R – Third Person Camera Addons** (collection by nanner; 19 mods incl. PUBG-style, Ghost Recon, MGS V presets) | https://steamcommunity.com/sharedfiles/filedetails/?id=2993007436 | Assorted infantry offsets; "some mention vehicle gameplay compatibility" | Mostly config, "some use scripts" | Infantry | Mixed; at least one APL-SA |
| **RE: 3RD** | https://steamcommunity.com/sharedfiles/filedetails/?id=2193899168 | Right-shoulder 3rd person + FOV for infantry | Config | Infantry | ? |
| **Personal Perspective** (Drakeziel, 2017, 1.3 KB, flagged incompatible) | https://steamcommunity.com/sharedfiles/filedetails/?id=918661981 | Shows full character in 3rd person; double-tap Numpad +/- for range of angles | Config | Infantry | ? |
| **3rd Person Camera close** (R. Hastings) | https://steamcommunity.com/sharedfiles/filedetails/?id=2849273982 | Title only (Steam 429) | Config (assumed) | Infantry | ? |
| **AutoCam** (Haleks, flagged incompatible) | https://steamcommunity.com/sharedfiles/filedetails/?id=2501417720 | Auto-switches 1st/3rd person by weapon state (lowered -> 3rd, raised/sprint -> 1st); requires 3rd person allowed by difficulty | Script switching the engine camera (`switchCamera`-style); no scripted camera object | Everything (engine camera) | Not public |
| **Head Range Plus – TrackIR Mod** | https://steamcommunity.com/sharedfiles/filedetails/?id=630737877 | Larger 1st-person head range in planes, helicopters, VTOLs, boats, tanks, cars with TrackIR; sets plane pilot FOV 0.75 -> 1 | Config: `ViewPilot` limits per listed vehicle class | Everything; changes nothing about roll/horizon | Not public; "no unauthorized modification" |
| **Helmet Mounted Camera** (Paradox, 44k subs) | https://steamcommunity.com/sharedfiles/filedetails/?id=2679569820 | Toggle a helmet-cam view (Shift+H / H via CBA keybind), laser dot (L), custom NVG (N) | Scripted camera during gameplay (player-controlled unit only) | **"Most of Arma 3 Interactions/features won't work while in Helmet Cam View"**; crosshair disabled; **vanilla NVG does not work** (they ship their own) | Not public |
| **Switchable Body Camera** (76 the Spider), **Squad Helmet Cameras** (117Briggy), **GoPro/Helmet camera** (West Valley), **Camera Co-Pilot** (Joey), **Clu's Custom Camera** (cluu), **Cute Cameras** (Scout) | ids 3131919989, 3033167364, 2265515385, 3038712053, 3171293845, 3762030615 | Found via Workshop search only; pages not readable (Steam 429). Unknown whether any is a gameplay-time view camera. | ? | ? | ? |
| **TGP Simple Cockpit Slew** (Ampersand) | https://steamcommunity.com/sharedfiles/filedetails/?id=2680118205 ; https://github.com/ampersand38/tgp-simple-cockpit-slew | Slew the pilot camera / AI turret / UAV turret from the cockpit with mouse while flying; stabilize on a world point; CCIP | CBA PFH; `inputAction "AimRight/AimLeft/AimUp/AimDown"` for mouse look while flying; a dummy display (`class tgp_main_mouseBlocker { idd = 86005; movingEnable = 0; ... }`) to keep mouse away from flight controls; `setPilotCameraRotation`, `setPilotCameraTarget`, `lineIntersectsSurfaces` / `terrainIntersectAtASL` for stabilization | Engine camera untouched (it drives the vehicle's pilot camera, not the view) | Public, **APL-SA** |
| Dev-branch thread **"Helicopter camera"** (2017) and Steam **"Changes in helicopter camera/controls?"** | https://forums.bohemia.net/forums/topic/204694-helicopter-camera/ (blocked) ; https://steamcommunity.com/app/107410/discussions/0/2741975115083048963 (+`?ctp=2`) | Not a mod: the source of the `extCameraParams` knowledge above; "Camera is fixed" by 30 May 2017. | — | — | — |

### B3. Spectator / cinematic / director cameras (player is not flying)

| Name | Link | Behaviour | Impl (loop, EH, commands) | Preserves | Src / license |
|---|---|---|---|---|---|
| **ACE3 spectator** (`ace_spectator`) | https://github.com/acemod/ACE3/tree/master/addons/spectator/functions | Free / follow (3PP orbit) / FPS modes, vision modes, focus tracking incl. targets in vehicles | `"CamCurator" camCreate`; `cameraEffect ["internal","back"]`; `camCommand` maxPitch/minPitch/speed/ceiling/"atl off"/"surfaceSpeed off"; `cameraEffectEnableHUD true`; **`addMissionEventHandler ["EachFrame", ...]` — comment: "follow camera requires EachFrame to avoid jitter"**; follow maths in `fnc_cam_prepareTarget` (dummy `Logic` + `BIS_fnc_setObjectRotation` + `modelToWorldVisualWorld`, then `setVectorDirAndUp [vectorDirVisual _dummy, vectorUpVisual _dummy]`); mouse deltas via display `MouseMoving` scaled by delta time; NVG/TI via `camUseNVG` / `setCamUseTI`; **FPS mode = `cameraEffect ["Terminate","BACK"]; _focus switchCamera "INTERNAL"`** | HUD via `cameraEffectEnableHUD`+`showHUD`; NVG/TI scripted; zoom scripted; no vehicle control (spectator) | Public, **GPL-2.0** |
| **BI End Game spectator** (`BIS_fnc_EGSpectatorCamera`) and **Splendid Camera** (`BIS_fnc_camera*`) | Extracted copies: https://github.com/porcinus/Arma-3/blob/master/Extracted/functions/fn_EGSpectatorCamera.sqf , fn_camera_init.sqf | BI's own; ACE spectator is a fork of the same design (same author, Nelson Duarte) | `camCreate eyePos player` (type "camcurator" or "camera"); `EachFrame` tick; `cameraEffectEnableHUD true`; `showHUD [true,false,...]` in FPS; `"SetCameraTransform"` = `setPosASL` + `setVectorDirAndUp`; Splendid Camera ticks all cameras from one `EachFrame` with `BIS_fnc_deltaTime` | as ACE | Game data (BI EULA) — read for technique, do not copy |
| **Simple Cinematic Camera** (Brominum) | https://steamcommunity.com/sharedfiles/filedetails/?id=3624526073 ; https://github.com/Brominum/Bro_SimpleCam | GCam successor: 6-DOF incl. **roll**, follow mode, look-at lock, **orientation lock to a vehicle's yaw/pitch/bank**, altitude lock, vision modes, controller support with deadzone, TFAR/ACRE | `"camera" camCreate`; `cameraEffect ["Internal","Back"]`; display `MouseMoving`/`MouseZChanged`/`KeyDown` handlers; `EachFrame` loop; `inputAction "AimRight"...` for sticks; `setPosASL` + `setVectorDirAndUp` + `camCommit 0` each frame; `camUseNVG`/`setCamUseTI` | HUD is the mod's own; player is a spectator | Public, **APL-SA** (README; no LICENSE file); README says core scripting "assisted by Google Gemini 3 Pro and Claude Code, then refined and optimized by human review" |
| **Streamator** (TaktiCool) | https://github.com/TaktiCool/Streamator/blob/master/addons/Streamator/Spectator/fn_cameraUpdateLoop.sqf | Streaming spectator: free/follow/shoulder/top-down/FPS/orbit | `inputAction "cameraMoveForward"/"cameraLookRight"...` (the engine's camera actions), time-based sin/cos angle smoothing, `setVectorDirAndUp [[sin d cos p, cos d cos p, sin p],[0,0,cos p]]`, `cameraEffectEnableHUD true`; FPS = `Terminate` + `switchCamera "INTERNAL"` | spectator | Public; license not asserted (no LICENSE file) |
| **GCam Cinematic Camera Tool** (Gigan, A3 port by Jezzaroony) | https://steamcommunity.com/sharedfiles/filedetails/?id=909893746 | Follow (F), behind view (B), HUD toggle (L) | Arma 2 era `sleep`-loop script; comments: input registered "only 4 updates per second despite 60fps", vehicle stutter, action not available while in a vehicle | — | Script in PBO (also mirrored in various DayZ mission repos) |
| **indiCam – independent camera** (woofer) | https://steamcommunity.com/sharedfiles/filedetails/?id=1372800247 ; thread 216403 (blocked) | "automatic camera robot" for a **second PC**: "the computer running it will not be able to participate in regular gameplay"; auto-switches angles by situation/visibility; F1–F10 keys | SQF scripted camera (`indiCam_core_main.sqf`); loop type unknown | Not a gameplay camera | Not public (no link) |
| **Dynamic Kill Camera** (parrygod1) | https://github.com/parrygod1/arma3-dynamickillcam | Slow-mo kill cam cutscene | `"camera" camCreate`, `camPrepareTarget`/`camPrepareRelPos`/`camCommitPrepared 0`, `cameraEffect ["external","back"]`, `camUseNVG` at night, `setAccTime 0.2` | cutscene | Public, no license file |
| **Domtaro UAV-like orbital camera** (gist) | https://gist.github.com/Domtaro/db7919b0bd1f4ec12eee51e244c84478 | Orbit cutscene | `EachFrame` mission EH; `setPosASL` on a `sin/cos` orbit; FOV by distance via `linearConversion` + `camPrepareFov`/`camCommitPrepared` | cutscene | gist |
| **KK's PiP/UAV tutorial** | https://killzonekid.com/arma-scripting-tutorials-uav-r2t-and-pip/ | r2t feed from a UAV | Camera `attachTo` UAV, then `addMissionEventHandler ["Draw3D", { _dir = (uav selectionPosition "PiP0_pos") vectorFromTo (uav selectionPosition "PiP0_dir"); cam setVectorDirAndUp [_dir, _dir vectorCrossProduct [-(dir select 1), _dir select 0, 0]]; }]` because "attached objects do not change direction automatically" | — | blog |
| **Olsen Framework / fparma (KEGs) / F3 / POTATO / TMF spectators** | e.g. https://github.com/dklollol/Olsen-Framework-Arma-3/blob/master/core/spectate.sqf ; https://github.com/fparma/fp-missions/.../spectator/FreeLookMovementHandler.sqf | Older spectator scripts | `camcreate` + `cameraeffect`; KEGs turns mouse deltas into yaw/pitch and applies with `setDir` + `bis_fnc_setpitchbank` | — | various |
| **ZEN camera** (`zen_camera`) | https://github.com/zen-mod/ZEN/tree/master/addons/camera | Only tunes the engine **curator** camera: `curatorCamera camCommand "atl on/off"`, `"surfaceSpeed"`, `"speedDefault"`, `"speedMax"`, `"maxPitch 89"` | No scripted camera | — | GPL-3.0 |
| **Achilles**, **Enhanced Movement**, **Advanced Rappelling**, **TPW MODS**, **Real Time Editor**, **MCC** | — | None is a player-view camera mod; MCC has a legacy `specta.sqf` spectator (same KEGs lineage as above). Not examined further. | — | — | — |

### B4. Code that reads the player's head / view direction every frame

| Source | What it reads and how | Notes |
|---|---|---|
| **AH-64D mod – `fza_ihadss_fnc_pnvsControl`** https://github.com/AH-64D-Apache-Official-Project/AH-64D/blob/master/addons/fza_ah64_ihadss/functions/fn_pnvsControl.sqf | `(( _heli vectorWorldToModelVisual getCameraViewDirection player) call CBA_fnc_vect2Polar) params ["_mag","_az","_el"];` then `BIS_fnc_clamp` to ±120° az / -45..20° el and drives the PNVS animation | Head-slaved sensor with freelook/TrackIR, engine camera active; license file present ("AH-64 Development Team", BI-style licence summary) |
| **a3vr-arma3 – `fn_stereoLoop.sqf`** https://github.com/gborgogno/a3vr-arma3/blob/master/addons/a3vr/functions/fn_stereoLoop.sqf | `EachFrame`: `_forward = vectorNormalized (getCameraViewDirection player); _up = [0,0,1]; ... _rightFlat = vectorNormalized (_forward vectorCrossProduct [0,0,1]); _up = vectorNormalized (_rightFlat vectorCrossProduct _forward); _right = ...; setPosWorld/ setVectorDirAndUp` on two `cameraEffect ["INTERNAL","BACK","a3vrleft"/"a3vrright"]` r2t cameras | This is a roll-free (horizon-up) basis built from the player's actual look direction. When their full-screen "proxy camera" is active they read `vectorDir/vectorUp A3VRHybrid_proxyCamera` instead; comment: "cameraEffect cannot mix a full-screen camera with RTT sources." |
| **CBA – `CBA_fnc_headDir`** https://github.com/CBATeam/CBA_A3/blob/master/addons/common/fnc_headDir.sqf | `positionCameraToWorld [0,0,0]` and `[0,0,10000]` -> azimuth; `_isExternalCam = distance > 2` | Comment: "positionCameraToWorld is only valid for player object" |
| **CBA – `CBA_fnc_viewDir`** (commy2) | soldiers: `getCameraViewDirection _vehicle`; vehicles: `vectorDir _vehicle` | |
| **CBA optics – `fnc_gunBank`** | screen-right = `positionCameraToWorld [0,0,0]` -> `[1,0,0]`, compared with weapon-up to get the bank angle of the weapon relative to the screen | A worked example of getting a *roll* angle out of the engine camera |
| **ACRE2 – `fnc_getHeadVector`** | same `positionCameraToWorld` trick, `[0,0,99999999]` | |
| **ACE3 viewports – `fnc_eachFrame`** | CBA PFH inside vehicles: `_eyesPosASL = AGLToASL (positionCameraToWorld [0,0,0]); _eyesDir = (AGLToASL (positionCameraToWorld [0,0,1])) vectorDiff _eyesPosASL;` then picks the vehicle viewport the player is looking at (< 45°) | Runs only when `cameraView == "INTERNAL"` and not turned out |
| **TGP Simple Cockpit Slew** | `inputAction "AimRight" - inputAction "AimLeft"` etc. on a CBA PFH | Bro_SimpleCam notes these actions "include BOTH the right stick AND the mouse axes" |
| **Bro_SimpleCam** | `inputAction "AimRight/AimLeft/AimUp/AimDown"` (sticks) with radial deadzone + cubic response; mouse via display `MouseMoving` | see (c) |
| `freeLook` (wiki blocked) | "returns if freelook is active on the current machine's controlled character" (search snippet) | Useful to gate deadzone logic on freelook state |

No source I found reads TrackIR axes directly; head tracking is only observable through the engine camera.

### B5. Forum threads with reusable facts (read)

- **Problem forcing camera view in vehicles** (166030): forcing a view while in a vehicle must use `vehicle player switchCamera "Internal"`, not `player switchCamera`, or the vehicle judders; the player keeps full vehicle control while the view is forced.
- **Enable free look manually / when attached** (193132): freelook is disabled while a unit is `attachTo`'d; there is no script command to force freelook on; the author intercepted Shift+Q/E with a KeyDown EH instead.
- **Modify 3rd pers. cam / better camera** (163426): `ViewPilot` angle/FOV limits, no way to stop the 3rd-person camera collision zoom.
- **Attach camera to man's head in vehicle** (213512): a camera attached to a unit detaches when the unit enters a vehicle; attach to `vehicle _unit` instead.
- **TrackIR helicopter view 3rd person** (225922): TrackIR also moves the 3rd-person orbit; only workaround is the TrackIR software toggle key.
- **NaturalPoint "Head roll in Arma 3"** (13085): head roll (TrackIR rZ) works in helicopters but not for infantry; unresolved.
- **Steam "3rd person view perspective changes when flying helicopters"**: the 3rd-person elevation drifts over a long flight and resets after landing/repair (uninvestigated engine behaviour).
- **Steam "Helicopter Free Look"**: users stuck in vehicle freelook; toggling the "Free look vehicles" option resets it.
- **Steam "Is there any way to fixate camera on jets?"**: in freelook/TGP modes the view "snaps back to center when toggled off unless controlled via axis input or TrackIR".

---

## (c) Best reference implementations to study

### C1. Seth Duda – Advanced Train Simulator / AI Command "3rd-person camera" (gameplay chase cam, horizon-level)

Files: `src/addons/ats/core/functions/camera/fn_enable3rdPersonCamera.sqf`, `fn_cameraUpdatePosition.sqf`, `fn_cameraMouseMoveHandler.sqf`, `fn_cameraMouseZoomHandler.sqf`, `fn_disable3rdPersonCamera.sqf`, `camera.h` (ATS, no license file) and the near-identical `AICommand/functions/remoteCamera/fn_enable3rdPersonCamera.sqf` (AIC, MIT).

Setup (verbatim, ATS):

```sqf
ATRAIN_3rd_Person_Camera = "camera" camCreate (_object modelToWorldVisual _modelPosition);
ATRAIN_3rd_Person_Camera cameraEffect ["internal", "BACK"];
ATRAIN_3rd_Person_Camera camSetFocus [-1, -1];
ATRAIN_3rd_Person_Camera camCommit 0;
ATRAIN_Mouse_Move_Handler = ["MAIN_DISPLAY","MouseMoving", "_this call ATRAIN_fnc_cameraMouseMoveHandler"] call ATRAIN_fnc_addEventHandler;
ATRAIN_Mouse_Zoom_Handler = ["MAIN_DISPLAY","MouseZChanged", "_this call ATRAIN_fnc_cameraMouseZoomHandler"] call ATRAIN_fnc_addEventHandler;
ATRAIN_3rd_Person_Camera_Frame_Handler = addMissionEventHandler ["EachFrame", {[] call ATRAIN_fnc_cameraUpdatePosition; false}];
```

Per-frame update (verbatim core):

```sqf
private _targetObject = vehicle ATRAIN_FNC_CAMERA_TARGET;
private _bbr = boundingBoxReal _targetObject;
private _maxHeight = abs (((_bbr select 1) select 2) - ((_bbr select 0) select 2));
private _targetModelPosition = ATRAIN_3rd_Person_Camera_Target_Model_Position vectorAdd [0,0,_maxHeight * 0.5];
private _targetPosition = AGLToASL (_targetObject modelToWorldVisual _targetModelPosition);
private _cameraPosition =  AGLToASL (_targetObject modelToWorldVisual (ATRAIN_FNC_CAMERA_REL_POSITION vectorAdd _targetModelPosition));
if((ASLToATL _cameraPosition) select 2 < 0) then { ... clamp pitch so camera stays above ground ... };
private _lookVector = _cameraPosition vectorFromTo _targetPosition;
private _cameraUpVector = (_lookVector vectorCrossProduct [0,0,1]) vectorCrossProduct _lookVector;
_cam setPosASL _cameraPosition;
_cam setVectorDirAndUp [_lookVector,_cameraUpVector];
```

where `ATRAIN_FNC_CAMERA_REL_POSITION` is a spherical offset in *model space* from mouse-accumulated yaw/pitch and wheel distance: `[d*cos(X)*sin(Y), d*sin(X)*sin(Y), d*cos(Y)]`, `Y` clamped 20..160°, distance 3..60 m, `distance <= 3` = "1st person" (camera moved onto the target point). Mouse handler adds `-(_this select 1)*0.2` degrees per unit of raw delta.

Why it matters: it is a working, gameplay-time, horizon-level (world-up) chase camera the player controls while driving. It also shows the map problem — on `ShowMap` key it runs `camera cameraEffect ["Terminate","Back"]; openMap true; waitUntil {!visibleMap}; camera cameraEffect ["internal","BACK"]`. Weaknesses to fix: it uses `EachFrame` (good) but computes camera position in the vehicle frame, so the *position* orbits with roll/pitch even though the *orientation* is horizon-level; no smoothing; no HUD/NVG handling (`cameraEffectEnableHUD` not called); no zoom/FOV.

### C2. ACE3 spectator (`fnc_cam`, `fnc_cam_tick`, `fnc_cam_prepareTarget`, `fnc_cam_setCameraMode`, `fnc_cam_setVisionMode`, `fnc_ui_handleMouseMoving`) — GPL-2.0

Creation (verbatim excerpts):

```sqf
private _camera = "CamCurator" camCreate _pos;   // "CamCurator required for engine driven controls"
_camera cameraEffect ["internal", "back"];
_camera setPosASL _pos; _camera setDir _dir;
_camera camCommand "maxPitch 89"; _camera camCommand "minPitch -89";
_camera camCommand "ceilingHeight 5000"; _camera camCommand "atl off"; _camera camCommand "surfaceSpeed off";
cameraEffectEnableHUD true;
GVAR(camDummy) = "Logic" createVehicleLocal ASLToAGL getPosASLVisual GVAR(camFocus);
// Start ticking (follow camera requires EachFrame to avoid jitter)
GVAR(camTick) = addMissionEventHandler ["EachFrame", {call FUNC(cam_tick)}];
```

Follow-camera placement each frame (`fnc_cam_prepareTarget`, verbatim core):

```sqf
private _focus = vehicle (param [0, objNull, [objNull]]);
// zoom interpolated per frame
_zoomTrue = (_zoomTrue * (1 - GVAR(camDeltaTime) * 10)) + (_zoom * GVAR(camDeltaTime) * 10);
private _bbd = [_focus] call BIS_fnc_getObjectBBD;
private _distance = (_bbd select 1) + _zoomTrue;
private _center = if (_isMan) then { _focus modelToWorldVisualWorld (_focus selectionPosition "Spine3") } else { _focus modelToWorldVisualWorld [0,0,_height] };
_dummy setPosASL _center;
[_dummy, [GVAR(camYaw), GVAR(camPitch), 0]] call BIS_fnc_setObjectRotation;   // roll = 0 -> horizon-level
GVAR(camera) setPosASL (_dummy modelToWorldVisualWorld [0, -_distance, 0]);
GVAR(camera) setVectorDirAndUp [vectorDirVisual _dummy, vectorUpVisual _dummy];
```

Mouse (`fnc_ui_handleMouseMoving`): `GVAR(camYaw) = ((GVAR(camYaw) + (_deltaX * 100 * GVAR(camDeltaTime)) + 180) % 360) - 180; GVAR(camPitch) = (((GVAR(camPitch) - (_deltaY * 100 * GVAR(camDeltaTime))) max -90) min 90);` with `camDeltaTime = diag_tickTime - last`.

Vision (`fnc_cam_setVisionMode`): `false setCamUseTI 0; camUseNVG (_newVision >= VISION_NVG);` or `true setCamUseTI _newVision;` — "Vision mode does not apply to fps view".

Mode switch (`fnc_cam_setCameraMode`): FPS = `_camera cameraEffect ["Terminate","BACK"]; _focus switchCamera "INTERNAL"; ... showHUD [true,false,false,false,false,false,false,true]`; FOLLOW = `_camera cameraEffect ["Internal","BACK"]; _focus switchCamera "EXTERNAL"; _camera camCommand "manual off"`; FREE = `switchCamera GVAR(camAgentFree)` ("Fix draw3D while in free camera for case where player is perma-dead") and `camCommand "manual on"`; always `cameraEffectEnableHUD true; showHUD _showHUD;`.

Also `fnc_cam_tick` re-targets when the focus gets in/out of a vehicle (`objectParent`). Related issue: "ace_spectator: Vision mode can't be changed in External camera" (#2774).

Why it matters: the most battle-tested SQF camera loop in the ecosystem; the yaw/pitch-on-a-dummy trick gives a horizon-level orbit for free; shows the exact HUD/vision/hand-back sequence and the `EachFrame` + `*Visual` requirement.

### C3. Bro_SimpleCam (`simplecam.sqf`) — APL-SA

Orientation lock decomposition of a vehicle's attitude (verbatim):

```sqf
private _refObj = vehicle _target;
private _tgtDir = getDirVisual _refObj;
private _vDir = vectorDirVisual _refObj;
private _vUp = vectorUpVisual _refObj;
private _tgtPitch = asin (_vDir select 2);
private _vSide = _vDir vectorCrossProduct _vUp;
private _tgtBank = (_vSide select 2) atan2 (_vUp select 2);
private _yawDes = _tgtDir + (_rotOffset select 0);
private _pitDes = _tgtPitch + (_rotOffset select 1);
_rollDes = _tgtBank + (_rotOffset select 2);
```

Per-frame smoothing and basis construction (verbatim):

```sqf
private _lerpAngle = { params ["_cur","_des","_t"]; private _diff = _des - _cur; _diff = _diff - (360 * floor((_diff + 180) / 360)); _cur + (_diff * _t) };
private _yawNew  = [_ang select 0, (_d get "AngDes") select 0, _rotSmooth] call _lerpAngle;
private _pitNew  = [_ang select 1, (_d get "AngDes") select 1, _rotSmooth] call _lerp;
private _rollNew = [_roll, _rollDes, _rollSmooth] call _lerpAngle;
private _vecDir = [sin(_yawNew) * cos(_pitNew), cos(_yawNew) * cos(_pitNew), sin(_pitNew)];
private _vecRightH = [cos(_yawNew), -sin(_yawNew), 0];
private _vecUpBase = _vecRightH vectorCrossProduct _vecDir;
private _vecUp = (_vecUpBase vectorMultiply cos(_rollNew)) vectorAdd (_vecRightH vectorMultiply sin(_rollNew));
...
_cam setPosASL _finalCamPos;
_cam setVectorDirAndUp [_vecDir, _vecUp];
_cam camCommit 0;
```

Input: display `MouseMoving` stores raw `[_x,_y]` deltas consumed once per frame (`_sens = cfgSens * fov` so sensitivity scales with zoom); wheel -> `FovDes` clamped 0.01..2.0; sticks via `inputAction "AimRight" - inputAction "AimLeft"` with radial deadzone `(_rs - dz*sign)/(1-dz)` and cubic response, and the important comment: "Arma's AimUp/Down/Left/Right actions include BOTH the right stick AND the mouse axes — so polling them while the mouse is moving would double-count the mouse delta". Vision: `camUseNVG false; false setCamUseTi 0` (normal), `camUseNVG true` (NVG), `true setCamUseTi 0/1` (WHOT/BHOT). Framerate-independent (`diag_deltaTime`).

Why it matters: it is the cleanest example of (1) computing a vehicle's yaw/pitch/bank from `vectorDirVisual`/`vectorUpVisual`, (2) building a dir+up pair with an explicit roll term (needed because `camSetBank` is broken), (3) exponential smoothing with angle wrap, (4) deadzone handling. The "orientation lock + offset" mode is structurally the inverse of what this mod needs (it *adds* the vehicle's bank; a horizon lock sets bank to 0 or to a smoothed/deadzoned fraction of it).

### Also worth a look
- **a3vr `fn_stereoLoop.sqf`**: the 8-line "take the player's actual view direction, strip roll by rebuilding the up vector from world-up" basis (section B4). This is the first-person horizon-lock operation in miniature — provided `getCameraViewDirection player` still reflects freelook/TrackIR when your own camera is active (untested).
- **AH-64D `fn_pnvsControl.sqf`**: head direction to vehicle space with clamps — the pattern for a per-axis deadzone/limit in the airframe frame.
- **TGP Simple Cockpit Slew**: reading mouse look with `inputAction "Aim*"` while the pilot flies, plus the `mouseBlocker` empty display used to stop those same axes reaching the cyclic.

---

## (d) What to borrow / what to avoid

### Borrow
1. **Loop and timing**: `addMissionEventHandler ["EachFrame", ...]` (ACE: "follow camera requires EachFrame to avoid jitter"), and only `*Visual` reads (`getPosASLVisual`, `vectorDirVisual`, `vectorUpVisual`, `modelToWorldVisualWorld`, `getDirVisual`) for anything you feed into `setPosASL`/`setVectorDirAndUp`. `Draw3D` also works (KK) but ACE needed a live agent (`switchCamera GVAR(camAgentFree)`) to keep Draw3D firing in some states — prefer `EachFrame`. Use `diag_deltaTime`/`diag_tickTime` deltas so smoothing is frame-rate independent (Bro, ACE, Streamator).
2. **Horizon-level orientation**: either `up = (dir × [0,0,1]) × dir` (ATS, a3vr) or explicit yaw/pitch/roll basis (Bro) or the ACE dummy-object trick (`BIS_fnc_setObjectRotation [yaw,pitch,0]` then copy `vectorDirVisual`/`vectorUpVisual`). Roll is impossible via `camSetBank`/`camPrepareBank` (documented non-functional).
3. **Attitude decomposition + deadzone + blend**: Bro's `pitch = asin(dir.z)`, `bank = atan2(side.z, up.z)`; wrap-aware angle lerp; radial deadzone with response curve; and, conceptually, vanilla `extCameraParams`' idea of blending horizon vs airframe by speed/height — a configurable `factor` between "world-stabilized" and "airframe-fixed" is exactly the design BI converged on for third person.
4. **HUD and vision**: `cameraEffectEnableHUD true` after `camCommit` (BI note), `showHUD [...]` for granular UI; re-apply `camUseNVG`/`setCamUseTI` when the player toggles NVG (ACE, Bro, Helmet Mounted Camera's failure is the counter-example). Test explicitly whether the 2D vehicle info panel / pilot HUD (`RscInGameUI*`) and the 3D MFD symbology render under a scripted camera — no source settles this; 3D MFD geometry should, 2D `unitInfoType` panels may not.
5. **Hand-back and lifecycle**: restore with `cam cameraEffect ["Terminate","BACK"]; camDestroy cam;` then `vehicle player switchCamera "INTERNAL"` (thread 166030 and ACE both use `switchCamera` on the vehicle/focus); terminate or hide while `visibleMap` (ATS), on death/respawn/get-out (ACE re-targets on `objectParent` change), and on mod unload — CineCam is remembered for a camera that "persisted after uninstall".
6. **Camera type**: `"camera"`, not `"CamCurator"`, unless you want the engine's WASD/mouse controls; if CamCurator, `camCommand "manual off"`.
7. **Input**: raw mouse deltas from `findDisplay 46` `MouseMoving` (ATS, Bro, ACE) for a deadzone/return-to-centre scheme; `inputAction "AimLeft/Right/Up/Down"` for sticks (remember they also contain the mouse); `freeLook` to know whether the player is in freelook; `cameraView`/`cameraOn` to know the engine state before you override it. TGP's `mouseBlocker` display shows how to stop mouse axes reaching the flight model, but for a *pilot* that is exactly what you must not do — only touch input while `freeLook` is true, or leave input entirely to the engine and just read the resulting head direction.
8. **Head direction**: `getCameraViewDirection player` (AH-64D, a3vr, CBA_fnc_viewDir) or `positionCameraToWorld [0,0,0]`/`[0,0,1]` (CBA_fnc_headDir, ACRE, ACE viewports), transformed with `vectorWorldToModelVisual` when you need airframe-relative angles. Plan a bench test of both while your own `cameraEffect` camera is active; if they freeze, fall back to (a) keeping the engine camera and only shifting `ViewPilot` limits via config, or (b) reading `inputAction` look axes yourself.
9. **Zero-script fallback**: a config patch setting `extCameraParams[] = {0, ...}` on `Helicopter` gives a horizon-following third-person camera with everything preserved; ship it as an option even if the scripted first-person mode is the headline feature.

### Avoid
1. `camSetBank` / `camPrepareBank` (broken), `attachTo` for cameras (orientation does not follow — KK; and unit attachments break on vehicle entry — thread 213512), `sleep`-loop cameras (GCam: 4 input updates/s, vehicle stutter), non-visual position/vector reads (one-frame lag = judder at 100+ km/h).
2. Assuming vanilla behaviours survive a scripted camera: Helmet Mounted Camera warns "Most of Arma 3 Interactions/features won't work while in Helmet Cam View", crosshair off, vanilla NVG off; ACE issue #2774 (vision mode stuck in external camera); zoom (RMB/Numpad +) does not touch a scripted camera — implement FOV yourself.
3. `switchCamera` on `player` instead of `vehicle player` while seated (judder, thread 166030).
4. Trying to script freelook on/off — no command exists (thread 193132); design the deadzone around the engine's freelook, not instead of it.
5. Mixing a full-screen `cameraEffect` with r2t/PiP cameras — a3vr had to release its full-screen camera first ("cameraEffect cannot mix a full-screen camera with RTT sources"); ACE viewports and TGP render targets will fight you.
6. Infantry `extCameraPosition` tricks — they are on `CAManBase` and irrelevant to vehicle seats.
7. Ignoring difficulty: a scripted external camera bypasses `thirdPersonView = 0/2`; check `difficultyOption "thirdPersonView"` and respect it, or servers will ban the mod.
8. Reproducing CineCam's failure modes: no vehicle support, motion sickness from aggressive weight/lag, breaking mission cutscenes that create their own cameras (check `cameraOn`/an existing `cameraEffect` before taking over).

---

## (e) Sources

### Read in full or in part (status noted)
- Steam: CineCam page https://steamcommunity.com/sharedfiles/filedetails/?id=1551751531 (read)
- Steam: Changes in helicopter camera/controls? https://steamcommunity.com/app/107410/discussions/0/2741975115083048963 and `?ctp=2` (read; dev quote and Hackwell's extCameraParams quote)
- Steam: 3rd person view perspective changes when flying helicopters https://steamcommunity.com/app/107410/discussions/0/1480982338942050419/ (read)
- Steam: Helicopter Free Look https://steamcommunity.com/app/107410/discussions/0/598198356168827847/ (read)
- Steam: Is there any way to fixate camera on jets? https://steamcommunity.com/app/107410/discussions/0/3069740688733444493/ (read)
- Steam: Helicopter camera control https://steamcommunity.com/app/107410/discussions/0/4762081419108468280/ (read; about the targeting camera)
- Steam: helicopter landing camera request https://steamcommunity.com/app/107410/discussions/0/3211505894125521146 (read)
- Steam: Head Range Plus https://steamcommunity.com/sharedfiles/filedetails/?id=630737877 (read)
- Steam: Helmet Mounted Camera https://steamcommunity.com/sharedfiles/filedetails/?id=2679569820 (read)
- Steam: Simple Cinematic Camera https://steamcommunity.com/sharedfiles/filedetails/?id=3624526073 (read)
- Steam: GCam https://steamcommunity.com/sharedfiles/filedetails/?id=909893746 (read)
- Steam: indiCam https://steamcommunity.com/sharedfiles/filedetails/?id=1372800247 (read)
- Steam: TGP Simple Cockpit Slew https://steamcommunity.com/sharedfiles/filedetails/?id=2680118205 (read)
- Steam: Personal Perspective https://steamcommunity.com/sharedfiles/filedetails/?id=918661981 (read)
- Steam: AutoCam https://steamcommunity.com/sharedfiles/filedetails/?id=2501417720 (read)
- Steam: A3R Third Person Camera Addons https://steamcommunity.com/sharedfiles/filedetails/?id=2993007436 (read)
- Steam: Third Person Camera Position Changer https://steamcommunity.com/sharedfiles/filedetails/?id=2582295355 (read)
- Steam: "Helicopter & Jet Training" https://steamcommunity.com/sharedfiles/filedetails/?id=928969898 (read; dead end)
- Steam Workshop text searches for "helicopter camera", "stabilized camera", "horizon camera" (read; result lists only)
- BI forums: Problem forcing camera view in vehicles https://forums.bohemia.net/forums/topic/166030-problem-forcing-camera-view-in-vehicles/ (read)
- BI forums: Enable free look manually https://forums.bohemia.net/forums/topic/193132-enable-free-look-manually-or-enable-free-look-when-attached/ (read)
- BI forums: Modify 3rd Pers. Cam / Better Camera https://forums.bohemia.net/forums/topic/163426-modify-3rd-pers-cam-better-camera/ (read)
- BI forums: Attach camera to man's head in vehicle https://forums.bohemia.net/forums/topic/213512-how-to-attach-camera-to-mans-head-who-in-vehicle/ (read)
- BI forums: TrackIr Helicopter view 3rd person https://forums.bohemia.net/forums/topic/225922-trackir-helicopter-view-3rd-person/ (read)
- NaturalPoint: Head roll in Arma 3 https://forums.naturalpoint.com/viewtopic.php?t=13085 (read); TrackIR 5 and TOH https://forums.naturalpoint.com/viewtopic.php?t=9821 (read; no technical content)
- BI blog: TOH TrackIR announcement https://www.bohemia.net/blog/turn-your-head-up-and-down-with-take-on-helicopters (read; marketing only)
- Wikipedia: Take On Helicopters https://en.wikipedia.org/wiki/Take_On_Helicopters (read)
- RHS feedback 0006256 https://feedback.rhsmods.org/view.php?id=6256 (read; pilot camera, not relevant)
- BI Wiki wikitext via API (read): cameraEffect, positionCameraToWorld, camSetBank, camPrepareBank, cameraEffectEnableHUD, camCommand, camUseNVG, cameraView, BIS_fnc_camFollow, Take_On_Helicopters:_Patches, Arma_3:_Difficulty_Settings — base URL https://community.bistudio.com/wiki/<Title>
- KK's blog, UAV/r2t/PiP https://killzonekid.com/arma-scripting-tutorials-uav-r2t-and-pip/ (read)
- Domtaro gist https://gist.github.com/Domtaro/db7919b0bd1f4ec12eee51e244c84478 (read)
- AH-64D docs, Head Tracking Mode https://ah-64d-apache-official-project.github.io/ui-headtracking.html (read; UI-level only)

### Source code read (GitHub raw)
- ACE3 spectator: https://github.com/acemod/ACE3/blob/master/addons/spectator/functions/fnc_cam.sqf , fnc_cam_tick.sqf , fnc_cam_prepareTarget.sqf , fnc_cam_setCameraMode.sqf , fnc_cam_setVisionMode.sqf , fnc_ui_handleMouseMoving.sqf , fnc_ui_handleMouseZChanged.sqf (GPL-2.0)
- ACE3 spike camera: https://github.com/acemod/ACE3/blob/master/addons/spike/functions/fnc_camera_update.sqf , fnc_camera_init.sqf
- ACE3 viewports: https://github.com/acemod/ACE3/blob/master/addons/viewports/functions/fnc_eachFrame.sqf
- CBA: https://github.com/CBATeam/CBA_A3/blob/master/addons/common/fnc_headDir.sqf , addons/common/fnc_viewDir.sqf , addons/optics/fnc_gunBank.sqf
- ACRE2: https://github.com/IDI-Systems/acre2/blob/master/addons/sys_core/fnc_getHeadVector.sqf
- ZEN camera: https://github.com/zen-mod/ZEN/tree/master/addons/camera (GPL-3.0)
- Bro_SimpleCam: https://github.com/Brominum/Bro_SimpleCam (simplecam.sqf, simplecam_key.sqf, config.cpp, README; APL-SA)
- Advanced Train Simulator: https://github.com/sethduda/AdvancedTrainSimulator/tree/master/src/addons/ats/core/functions/camera (no license file)
- AI Command: https://github.com/sethduda/AIC/blob/master/AICommand/functions/remoteCamera/fn_enable3rdPersonCamera.sqf (MIT per README)
- a3vr-arma3: https://github.com/gborgogno/a3vr-arma3/blob/master/addons/a3vr/functions/fn_stereoLoop.sqf (license file present, SPDX not asserted)
- AH-64D: https://github.com/AH-64D-Apache-Official-Project/AH-64D/blob/master/addons/fza_ah64_ihadss/functions/fn_pnvsControl.sqf (project licence file present)
- TGP Simple Cockpit Slew: https://github.com/ampersand38/tgp-simple-cockpit-slew (fnc_handleSlew.sqf, fnc_inputSlewAnalog.sqf, fnc_setStabilization.sqf, config/mouseBlocker.hpp, config/CfgUserActions.hpp; APL-SA)
- Streamator: https://github.com/TaktiCool/Streamator/blob/master/addons/Streamator/Spectator/fn_cameraUpdateLoop.sqf (no license file)
- VKN 3PPCam: https://github.com/56curious/VKN_Official_Mod/tree/master/VKN_Functions/Functions/3PPCam (APL-ND per header)
- Dynamic Kill Camera: https://github.com/parrygod1/arma3-dynamickillcam (no license)
- fparma KEGs spectator: https://github.com/fparma/fp-missions/blob/master/Arma%203/fp-co45@convoyoperationsv03.altis/spectator/FreeLookMovementHandler.sqf
- Olsen Framework: https://github.com/dklollol/Olsen-Framework-Arma-3/blob/master/core/spectate.sqf
- BI extracted functions (technique only): https://github.com/porcinus/Arma-3/blob/master/Extracted/functions/fn_EGSpectatorCamera.sqf , fn_camera_init.sqf
- extCameraParams in the wild: https://github.com/AdmiralScorpii/340th_MRD_Aux_Mod/blob/master/mavik/config.cpp , https://github.com/Legion-Studios/LegionCore-Public/blob/master/addons/vehicles_105k/CfgVehicles.hpp , https://github.com/pastoman/Arma-3-Portable-Drone-mod/blob/master/addons/main/config.cpp

### Found but NOT readable (dead or blocked for me)
- BI forums dev branch "Helicopter camera" https://forums.bohemia.net/forums/topic/204694-helicopter-camera/ (Cloudflare; page 3 holds the extCameraParams explanation per Hackwell)
- BI forums CineCam https://forums.bohemia.net/forums/topic/220040-wip-cinecam-cinematic-third-person-camera-replacement/ (Cloudflare)
- BI forums indiCam https://forums.bohemia.net/forums/topic/216403-indicam-independent-camera-mod/ (Cloudflare)
- BI forums Helmet Mounted Displays MOD https://forums.bohemia.net/forums/topic/170973-helmet-mounted-displays-mod/ (Cloudflare)
- BI forums Camera script to follow tank turret https://forums.bohemia.net/forums/topic/181544-camera-script-to-follow-tank-turret/ (403)
- BI forums Third Person view for Aircraft? https://forums.bohemia.net/forums/topic/224139-third-person-view-for-aircraft/ (403)
- BI forums VPHUD https://forums.bohemia.net/forums/topic/203881-vphud-virtual-pilot-head-up-display/ (not attempted after blocks)
- BI Wiki: CfgVehicles_Config_Reference, getCameraViewDirection, TrackIR, inputAction, freeLook, eyeDirection, Arma_3:_Field_Manual_-_Vehicle_Controls, Arma_3:_Jets (Cloudflare / missing)
- arma3.com/whatsnew/helicopters (DNS failure twice)
- Steam items 3038712053, 3131919989, 3171293845, 3762030615, 2849273982, 1284600102 (HTTP 429 at the end of the session)
- Reddit (r/arma, r/armadev) is not accessible to the search tool at all; armaholic is dead and its mirrors did not surface in results.
