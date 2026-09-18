#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"

// Settings are registered on every machine (CBA needs that for the Eden addon options);
// all seven are client-side (isGlobal 0).

[QGVAR(enabled), "CHECKBOX",
    ["Enabled", "Master switch. Off means the vanilla view."],
    "Helicopter Horizon Lock", true, 0
] call CBA_fnc_addSetting;

[QGVAR(autoOn), "CHECKBOX",
    ["Start levelled when entering a helicopter", "Switch the levelled view on whenever you take a helicopter seat."],
    "Helicopter Horizon Lock", true, 0
] call CBA_fnc_addSetting;

[QGVAR(pitchLimit), "SLIDER",
    ["Pitch limit", "Degrees of nose pitch cancelled before the view starts following the aircraft. 90 keeps the horizon level at any pitch."],
    "Helicopter Horizon Lock", [0, 90, 90, 0], 0
] call CBA_fnc_addSetting;

[QGVAR(rollLimit), "SLIDER",
    ["Roll limit", "Degrees of bank cancelled before the view starts following the aircraft. 90 keeps the horizon level at any bank; the engine stops head roll at 45 degrees."],
    "Helicopter Horizon Lock", [0, 45, 45, 0], 0
] call CBA_fnc_addSetting;

[QGVAR(pitchOffset), "SLIDER",
    ["View pitch offset", "Degrees added to the levelled view, positive looks up. 0 keeps the aircraft's default head angle."],
    "Helicopter Horizon Lock", [-20, 20, 0, 0], 0
] call CBA_fnc_addSetting;

private _slots = [""];
private _slotTitles = ["None"];
for "_i" from 1 to 20 do {
    _slots pushBack format ["User%1", _i];
    _slotTitles pushBack format ["Use Action %1", _i];
};
[QGVAR(toggleSlot), "LIST",
    ["Joystick toggle slot", "Custom control that toggles the levelled view. Bind it to a joystick button under Configure > Controls > Custom."],
    "Helicopter Horizon Lock", [_slots, _slotTitles, 0], 0
] call CBA_fnc_addSetting;

[QGVAR(autoRegister), "CHECKBOX",
    ["Register the head tracker automatically", "Write the registry value that makes Arma 3 load the mod's head tracker. Never overwrites another tracker's value."],
    "Helicopter Horizon Lock", true, 0
] call CBA_fnc_addSetting;

ADDON = true;
