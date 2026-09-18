# Horizon-locked helicopter camera for Arma 3: research summary

Date: 2026-09-18. Priority: **first person** (user decision). Third person secondary.
Target: Arma 3 v2.22 (installed on this PC), not Arma Reforger.

Files in this folder:

| File | Contents |
|------|----------|
| 00-design-notes.md | Goal, the deadzone/drag function, composition order, non-goals |
| 01-camera-mechanics.md | Engine vs scripted cameras, verbatim command docs, breakage table, 15 in-game tests |
| 02-prior-art.md | Existing mods and scripts, three reference camera loops, borrow/avoid list |
| 03-tooling-and-structure.md | HEMTT, CBA APIs, project tree with file contents, first-run checklist |
| 04-local-environment.md | What is installed on this PC and what is missing |

Source caveat: the Bohemia wiki and forums sit behind a bot check that blocked
direct fetches all session. The reports quote wiki text via the MediaWiki API and
archived snapshots from 2025, and mark anything that could not be verified.

## Verdict

1. **First person needs a scripted camera. There is no engine hook.** The full
   camera command group and every command added in 2.10 through 2.22 were checked.
   Nothing re-orients the engine's pilot view at runtime. The pilot-view config
   class only clamps head angles, head translation and field of view. The camera
   bank and dive commands are documented as non-functional. High confidence.
2. **Nothing existing does this.** No Workshop or GitHub mod stabilises the
   pilot's own first-person view during gameplay. Spectator and cinematic
   cameras all hand first person back to the engine.
3. **The scripted-camera pattern is proven on a helicopter.** The Project Hatchet
   UH-60 mod ships a full-screen scripted camera used from a crew seat in flight.
   It creates a camera, enters it with the internal camera effect, and every frame
   writes position and orientation from render-scope reads with the up vector
   supplying roll. That is exactly the loop this mod needs, so rendering stability
   at helicopter speeds is not in doubt.
4. **What is in doubt is everything the engine used to do for free.** The UH-60
   author reports that some user actions stop firing while the scripted camera is
   active and had to hook raw key input. Whether the pilot keeps full flight
   control, whether freelook and TrackIR remain readable, and whether the
   helicopter's HUD symbology draws are all undocumented. These are in-game tests,
   not research questions.
5. **Third person has a vanilla knob.** The vehicle config param
   `extCameraParams[]` (Arma 3 1.70) blends the external camera between horizon-
   following and attitude-following by speed and height. Vanilla helicopters ship
   the legacy value. A config-only patch gives a horizon-following third person
   with nothing lost, but it is config-time only, so it cannot do the drag rule.
6. **Per-frame loop choice is settled.** ACE3 spectator, the UH-60 mod and BI's
   own spectator use the EachFrame mission event handler with the `*Visual`
   position and vector commands. CBA's per-frame handler is registered with
   EachFrame under the hood (verified from CBA source), so a delay-0 CBA handler is
   the idiomatic equivalent. Roll goes through `setVectorDirAndUp`.

## Head pose: the two candidate designs

Which one the mod uses is decided by test T2 below.

- **Design A, reuse the engine's head.** If `getCameraViewDirection player` still
  follows freelook and TrackIR while the scripted camera is active, transform it
  into the airframe frame, then compose it onto the levelled basis. Freelook,
  TrackIR and the head-angle limits all keep working with no input code.
- **Design B, re-implement the head.** If it does not, poll the analog look
  actions (`lookLeftCont`, `lookUpCont`, and so on; their default bindings are the
  tracking-device axes) plus the freelook modifier, integrate them into a head
  model clamped to the vehicle's pilot-view limits. TrackIR survives only through
  those axes. Fallback for actions that read zero under the camera: raw key and
  mouse handlers on the main display, matched against `actionKeys`.

## First-person risk list, in test order

| # | Test | Why it matters | If it fails |
|---|------|----------------|-------------|
| T1 | Flight controls while a scripted camera is primary: collective, cyclic, pedals, mouse-cyclic, joystick, fire, targeting, gear, autohover | Blocking. If the pilot loses control, the whole approach changes | Try the `switchCamera` proxy-object trick (hidden object attached to the vehicle, oriented per frame); if that also fails, first person is not achievable this way |
| T2 | Does `getCameraViewDirection player` still follow freelook and TrackIR under the scripted camera? | Chooses Design A or B above | Design B |
| T4 | With HUD re-enabled after commit: 2D vehicle info panel, radar, and the AH-99 class MFD helmet symbology | Hover without velocity vector and radar altitude is a regression on some airframes | Redraw the essentials with drawIcon3D / a cutRsc overlay, or accept it as a mode trade-off |
| T4b | Is the cockpit rendered from the model's View-Pilot LOD (detailed interior, live instrument and MFD textures) or from the exterior resolution LOD? The engine uses the pilot LOD only for its own pilot view; a scripted camera most likely gets the exterior LOD | Blank gauges or glass artefacts would make first person unpleasant even if everything else works | Accept lower cockpit fidelity, or hide the vehicle and render a second copy (not viable); mostly a trade-off to document |
| T3 | `inputAction` values for look, zoom, NVG and view-toggle actions under the scripted camera | Feeds Design B and zoom/NVG mirroring | Raw display handlers plus actionKeys |
| T14 | Does `getObjectFOV` track RMB and numpad zoom under the scripted camera? | Lets zoom mirror the engine instead of re-implementing it | Drive `camSetFov` from the zoom actions with the pilot-view FOV limits |
| T8 | NVG and thermal toggles | Night flying | Mirror on the VisionModeChanged event with `camUseNVG` / `setCamUseTI` |
| T10 | Eject, get out, seat switch, death, vehicle destroyed, respawn, map open | Prior art shows cameras left running and juddering hand-backs | Release on every event; terminate the effect before destroying the camera |
| T11 | Eye anchor: sample `positionCameraToWorld [0,0,0]` at activation, convert to model space, re-apply per frame | Camera must sit where the engine camera sat | Compare with `eyePos` and the `pilot` memory point |
| T7 | PiP mirrors and MFD render-to-texture while the full-screen camera is up | Known conflict in a3vr and the UH-60 mod | Re-issue the r2t effects on release; document as a limitation |
| T12 | `supportInfo` on the two 2.22 commands `enableFreeLook` and `getAimDirectionAndUp` | Their pages were unreachable; a script-side freelook toggle would help Design A | None needed, informational |
| T13 | Vanilla third-person roll and pitch with the legacy vs patched `extCameraParams[]` | Decides whether third person needs any script at all | Scripted third-person mode using the same loop |

Full test descriptions with the exact values to print are in 01-camera-mechanics.md
section (d), tests T1 to T15.

## Recommended plan

**Step 1, feasibility in the debug console, no addon yet.** Done as a harness:
`tests/feasibility/horizoncam_test.sqf` with the procedure in
`tests/feasibility/README.md`. It takes over the camera, applies the deadzone,
and prints the T1 to T4, T8, T11 and T14 values on screen and to the RPT. This is
the go/no-go for the first-person idea. Expect an evening.

**Step 2, the addon.** Subscribe to CBA, install HEMTT via winget, create the project
from the tree in 03-tooling-and-structure.md, port the working loop into a CBA
per-frame handler, add settings for pitch limit, roll limit, smoothing, enable, and
a toggle keybind, and add a config patch for third person if T13 shows it is worth
having. Client-side only. Respect the server's third-person difficulty setting.

**Step 3, polish.** Head model or head reuse per T2, zoom and NVG mirroring, lifecycle
release, then sign and publish.

## Setup facts for this PC

Arma 3 2.22 and Arma 3 Tools are installed on B:. CBA_A3 is not subscribed and
HEMTT is not installed. Both are prerequisites for step 2; see 04-local-environment.md.

## Update after in-game feasibility runs (2026-09-18)

See `tests/feasibility/RESULTS.md` for the evidence. Summary:

- Every cutscene-camera method (camCreate + cameraEffect) makes the engine stop
  delivering input to the helicopter. Switching the engine view onto a proxy object
  is worse. Neither is usable for a pilot.
- The only method that keeps flight control is a render-to-texture camera drawn
  full-screen over the still-primary engine pilot view. It works but costs picture
  quality, shows the pilot's head, and needs HUD, zoom and NVG mirroring.
- New candidate direction: drive the engine's own head (which has yaw, pitch and
  roll freedom in helicopters) instead of replacing the camera. No script command
  sets the head pose; the realistic route is a virtual head-tracking device fed by
  the mod through a small extension (opentrack / TrackIR protocol). Cheap in-engine
  experiments first: `doWatch` a levelled point (harness head mode 3) and check
  `supportInfo "n:enableFreeLook"`.
