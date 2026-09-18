#include "script_component.hpp"

if (!hasInterface) exitWith {};

GVAR(active) = false;     // session toggle: levelled view wanted
GVAR(levelling) = false;  // a pose was sent last frame, so a zero pose is due when levelling stops
GVAR(slotHeld) = false;
GVAR(lastTick) = 0;
GVAR(prevPitch) = 0;
GVAR(prevRoll) = 0;

// the tracker DLL keeps the last pose across missions
"hhl" callExtension "zero";

["Helicopter Horizon Lock", QGVAR(toggle), "Toggle levelled view",
    { GVAR(active) = !GVAR(active); true }, "",
    [0x23, [true, true, false]] // DIK_H with Shift and Ctrl
] call CBA_fnc_addKeybind;

["vehicle", {
    params ["", "_newVehicle"];
    if (GVAR(autoOn) && {_newVehicle isKindOf "Helicopter"}) then { GVAR(active) = true; };
}, true] call CBA_fnc_addPlayerEventHandler;

[FUNC(onFrame), 0] call CBA_fnc_addPerFrameHandler;

["CBA_settingsInitialized", { call FUNC(selfCheck); }] call CBA_fnc_addEventHandler;
