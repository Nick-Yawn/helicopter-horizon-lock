# Horizon-locked helicopter camera for Arma 3: design notes

Status: pre-research thinking, written 2026-09-18. Research findings live in
01-camera-mechanics.md, 02-prior-art.md and 03-tooling-and-structure.md.

## Goal

While the player is piloting a helicopter, keep the camera's pitch and roll
level with the horizon so the airframe visibly tilts around a fixed horizon.
Motivation: better attitude cues in a hover.

**Priority (user, 2026-09-18): first person.** Third person is a nice-to-have.
Prior-art research found that vanilla Arma 3 already has a third-person
pitch blend (`extCameraParams[]`, see 02-prior-art.md), so third person may be
partly achievable with a config patch alone. First person has no such knob and
no known mod scripts the pilot's own view during gameplay; ACE3 and BI
spectator both hand first person back to the engine camera. Expect the hard
problems (HUD symbology, freelook, TrackIR, zoom, NVG) to all live here.

Past a configurable angle (default 30 degrees) the helicopter "drags" the camera
with it at that fixed offset, so extreme attitudes never leave the camera looking
at nothing useful.

## The stabilisation function

Let `a` be the helicopter's pitch (or roll) relative to the horizon and `L` the
configured limit for that axis. The camera's pitch (or roll) relative to the
horizon is

    cam(a) = a - clamp(a, -L, +L)

which is a deadzone:

| heli attitude a | camera attitude cam(a) | camera offset from airframe |
|-----------------|------------------------|-----------------------------|
| 0               | 0                      | 0                           |
| +20 (L = 30)    | 0                      | -20                         |
| +30             | 0                      | -30                         |
| +45             | +15                    | -30 (saturated)             |
| -60             | -30                    | +30 (saturated)             |

Yaw always follows the helicopter heading. Pitch and roll get independent limits.

Refinements to consider once the basic version works:

- Smoothing (exponential low-pass on the camera attitude) so the transition into
  and out of the saturated region is not a hard corner, and so simulation jitter
  does not reach the camera.
- A gain factor (0 = fully locked to horizon, 1 = normal Arma behaviour) as an
  alternative or complement to the hard limit.
- Separate settings for first person and third person.
- Optional: leave yaw partially decoupled too (lagging heading), which some
  players like in third person. Out of scope for v1.

## Camera composition order (first person)

Final camera orientation = heading(yaw) * stabilised(pitch, roll) * head(freelook/TrackIR)

Position = helicopter pilot eye position each frame (must be the *Visual variant
so it matches what is rendered this frame).

## Camera composition order (third person)

Position = helicopter position + R(yaw only, plus stabilised pitch/roll) * external offset.
Orientation = same as first person minus the head term (or with freelook orbit).

## Things I believe are true and want research to confirm

1. The engine's own internal/external cameras cannot be re-oriented from script;
   only their static limits are configurable.
2. A scripted camera (camCreate + cameraEffect) can be repositioned and
   re-oriented every frame with full roll control.
3. A scripted camera hides the 2D HUD unless explicitly re-enabled, and may not
   render the helicopter's HUD symbology (class MFD) at all.
4. Freelook, TrackIR, zoom, NVG and thermal are lost under a scripted camera
   unless the mod re-implements them; some can be read back from script, some
   cannot.
5. Per-frame camera updates should use a render-synchronised handler and the
   *Visual position/vector commands to avoid one-frame lag.

## Non-goals for v1

- No changes to flight model or controls.
- No server component. Purely client-side.
- No gunner/co-pilot seats (pilot seat only), unless it falls out for free.
