#include "script_component.hpp"
/*
 * Runs every frame. Polls the custom-action toggle, then either sends the head
 * counter-rotation that levels the view or, when levelling stops, one zero pose.
 */

// signed shortest angle in degrees
#define WRAP(a) ((a) - 360 * floor (((a) + 180) / 360))

// held look actions, which the engine adds on top of the head pose; the *Cont ones are the
// head tracker's own axes, i.e. our pose read back, so they are left out
#define LOOK_ACTIONS ["lookAround", "lookLeft", "lookRight", "lookLeftDown", "lookDown", "lookRightDown"]

if (GVAR(toggleSlot) != "") then {
    if (inputAction GVAR(toggleSlot) > 0.5) then {
        if (!GVAR(slotHeld)) then {
            GVAR(slotHeld) = true;
            GVAR(active) = !GVAR(active);
        };
    } else {
        GVAR(slotHeld) = false;
    };
};

private _veh = objectParent player;
private _level = GVAR(enabled) && GVAR(active) && {cameraView == "INTERNAL"} && {_veh isKindOf "Helicopter"}
    && {driver _veh == player} && {LOOK_ACTIONS findIf {inputAction _x > 0} == -1};

if (!_level) exitWith {
    if (GVAR(levelling)) then {
        GVAR(levelling) = false;
        "hhl" callExtension "zero";
    };
};

private _wasLevelling = GVAR(levelling);
GVAR(levelling) = true;
if (uiNamespace getVariable [QGVAR(checkPolls), false]) then {
    uiNamespace setVariable [QGVAR(checkPolls), false];
    // "status" carries the engine's poll count; it must rise while the view is levelled
    [{
        if (("hhl" callExtension "status") isEqualTo _this) then {
            hint "Helicopter Horizon Lock: enable FreeTrack under Options > Controls > Controllers.";
        };
    }, "hhl" callExtension "status", 3] call CBA_fnc_waitAndExecute;
};

// airframe attitude: pitch nose-up positive, roll right-wing-down positive
private _d = vectorNormalized (vectorDirVisual _veh);
private _u = vectorNormalized (vectorUpVisual _veh);
private _yaw = (_d select 0) atan2 (_d select 1);
private _pitch = asin (((_d select 2) min 1) max (-1));
private _right0 = [cos _yaw, -(sin _yaw), 0];
private _roll = (_u vectorDotProduct _right0) atan2 (_u vectorDotProduct (_right0 vectorCrossProduct _d));

// one frame of prediction, because the pose sent now is rendered next frame: add the
// last frame's change, unless levelling has just started
private _pPred = _pitch;
private _rPred = _roll;
if (_wasLevelling) then {
    _pPred = _pitch + WRAP(_pitch - GVAR(prevPitch));
    _rPred = _roll + WRAP(_roll - GVAR(prevRoll));
};
GVAR(prevPitch) = _pitch;
GVAR(prevRoll) = _roll;

// head = -clamp(a, -L, +L) per axis, plus the view pitch offset
private _headP = GVAR(pitchOffset) - (((WRAP(_pPred)) max (-GVAR(pitchLimit))) min GVAR(pitchLimit));
private _headR = -(((WRAP(_rPred)) max (-GVAR(rollLimit))) min GVAR(rollLimit));

// FreeTrack signs: pitch positive = look up (as ours), roll positive = roll left (inverted).
// The engine scales the value by 2 pi on pitch and pi on roll (measured, native/README.md).
// Integer millidegrees so Arma never formats the numbers in scientific notation.
"hhl" callExtension ["pose", [0, round (_headP * 1000 / (2 * pi)), round (-_headR * 1000 / pi)]];
